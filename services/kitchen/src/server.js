// Daig kitchen service - the application.
// Decides accept/reject, then asks dispatch for a rider.
'use strict';

const express = require('express');
const { request } = require('undici');
const { registry, httpMetrics, ordersTotal } = require('../../_shared/metrics');
const { makePool } = require('../../_shared/db');
const log = require('../../_shared/logger').build('kitchen');

const SERVICE = 'kitchen';

/**
 * DELIBERATE DEFECT - Day 4 profiling exercise.
 *
 * Surge pricing based on how busy each area is. The intent is fine; the
 * implementation loops over the same array twice, which is O(n^2) and dominates
 * the CPU profile once a few hundred orders are open.
 *
 * A continuous profile makes this obvious in about ten seconds. Reading the code
 * makes it obvious in about ten minutes. That gap is the lesson.
 */
function computeSurgeScore(openOrders) {
  if (process.env.CHAOS_HOT_SURGE_LOOP !== 'true') {
    const byArea = new Map();
    for (const o of openOrders) byArea.set(o.customer_area, (byArea.get(o.customer_area) || 0) + 1);
    let max = 0;
    for (const n of byArea.values()) max = Math.max(max, n);
    return 1 + Math.min(max / 25, 1.5);
  }

  let worst = 0;
  for (let i = 0; i < openOrders.length; i++) {
    let sameArea = 0;
    for (let j = 0; j < openOrders.length; j++) {          // <-- the defect
      if (openOrders[i].customer_area === openOrders[j].customer_area) sameArea++;
      Math.sqrt(sameArea * (j + 1));   // makes the frame unmistakable in a flame graph
    }
    worst = Math.max(worst, sameArea);
  }
  return 1 + Math.min(worst / 25, 1.5);
}

module.exports = function startServer(config) {
  const PORT = Number(process.env.PORT || 3002);
  const DISPATCH_URL = process.env.DISPATCH_URL || 'http://dispatch:3003';
  const { q } = makePool(SERVICE, config.DATABASE_URL);

  log.info({ credential_source: config.source }, 'configuration resolved');

  const app = express();
  app.use(express.json({ limit: '64kb' }));
  app.use(httpMetrics(SERVICE));

  app.get('/healthz', (_req, res) => res.json({ ok: true, service: SERVICE }));
  app.get('/readyz', async (_req, res) => {
    try { await q('ready_check', 'SELECT 1'); res.json({ ok: true, service: SERVICE }); }
    catch (e) { res.status(503).json({ ok: false, error: 'database unreachable' }); }
  });
  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  app.post('/api/kitchen/accept', async (req, res) => {
    const { order_id, customer_area } = req.body || {};
    if (!order_id) return res.status(400).json({ error: 'order_id required' });

    const { rows: [order] } = await q('get_order',
      `SELECT o.id, o.state, r.is_open, r.prep_minutes
         FROM orders o JOIN restaurants r ON r.id = o.restaurant_id
        WHERE o.id = $1`, [order_id]);
    if (!order) return res.status(404).json({ error: 'order not found' });

    const { rows: open } = await q('open_orders',
      `SELECT customer_area FROM orders
        WHERE state IN ('PLACED','ACCEPTED','COOKING','READY')`);
    const surge = computeSurgeScore(open);

    const accepted = order.is_open;
    const next = accepted ? 'ACCEPTED' : 'REJECTED';

    await q('update_state', 'UPDATE orders SET state=$1, updated_at=now() WHERE id=$2',
      [next, order_id]);
    await q('append_event',
      `INSERT INTO order_events (order_id, from_state, to_state, actor)
       VALUES ($1,$2,$3,'kitchen')`, [order_id, order.state, next]);
    ordersTotal.inc({ state: next });

    log.info({ order_id, next, surge: Number(surge.toFixed(2)), open_orders: open.length },
      'kitchen decision');

    if (!accepted) return res.json({ order_id, state: next, reason: 'restaurant closed' });

    let assignment = { ok: false };
    try {
      const r = await request(`${DISPATCH_URL}/api/dispatch/assign`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ order_id, customer_area }),
        headersTimeout: 15000,
        bodyTimeout: 15000
      });
      assignment = { ok: r.statusCode < 400, status: r.statusCode };
    } catch (err) {
      log.error({ err: err.message, order_id }, 'dispatch call failed');
      assignment = { ok: false, error: err.message };
    }

    res.json({
      order_id,
      state: next,
      prep_minutes: order.prep_minutes,
      surge_multiplier: Number(surge.toFixed(2)),
      assignment
    });
  });

  const server = app.listen(PORT, () => log.info({ port: PORT }, `${SERVICE} listening`));
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
  return server;
};
