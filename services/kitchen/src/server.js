// Daig kitchen service - the application.
// Decides accept/reject, then asks dispatch for a rider.
'use strict';

const express = require('express');
const { request } = require('undici');
const { registry, httpMetrics, ordersTotal } = require('../../_shared/metrics');
const { makePool } = require('../../_shared/db');
const { installGracefulShutdown } = require('../../_shared/shutdown');
const { computeSurgeScore } = require('./surge');
const log = require('../../_shared/logger').build('kitchen');

const SERVICE = 'kitchen';

module.exports = function startServer(config) {
  const PORT = Number(process.env.PORT || 3002);
  const DISPATCH_URL = process.env.DISPATCH_URL || 'http://dispatch:3003';
  const { pool, q } = makePool(SERVICE, config.DATABASE_URL);

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
  installGracefulShutdown({ server, pool, log });
  return server;
};
