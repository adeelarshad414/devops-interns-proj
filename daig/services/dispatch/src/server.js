// Daig dispatch service - the application.
// Finds a rider. Contains the Day 4 latency defect.
'use strict';

const express = require('express');
const { registry, httpMetrics } = require('../../_shared/metrics');
const { makePool } = require('../../_shared/db');
const log = require('../../_shared/logger').build('dispatch');

const SERVICE = 'dispatch';

module.exports = function startServer(config) {
  const PORT = Number(process.env.PORT || 3003);
  const { q } = makePool(SERVICE, config.DATABASE_URL);

  log.info({ credential_source: config.source }, 'configuration resolved');

  /**
   * DELIBERATE DEFECT - Day 4 tracing exercise.
   *
   * Finding a rider should be one query. With CHAOS_SLOW_DISPATCH=true it
   * becomes an N+1: one query for the rider list, then one per rider to count
   * their open assignments. With no index on assignments(rider_id) this reaches
   * multiple seconds under the iftar load.
   *
   * The trace shows it immediately - one span with dozens of sequential child
   * database spans. The metrics only say "dispatch is slow", which is why you
   * need both.
   */
  async function pickRider(area) {
    const slow = process.env.CHAOS_SLOW_DISPATCH === 'true';

    if (!slow) {
      const { rows } = await q('pick_rider_fast',
        `SELECT r.id, r.name,
                count(a.id) FILTER (WHERE a.state = 'ASSIGNED') AS load
           FROM riders r
           LEFT JOIN assignments a ON a.rider_id = r.id
          WHERE r.is_on_shift AND ($1::text IS NULL OR r.area = $1)
          GROUP BY r.id
          ORDER BY load ASC, random()
          LIMIT 1`, [area]);
      return rows[0] || null;
    }

    const { rows: riders } = await q('list_riders',
      'SELECT id, name FROM riders WHERE is_on_shift AND area = $1', [area]);
    if (!riders.length) return null;

    const scored = [];
    for (const r of riders) {
      // One round trip per rider. This is the N+1.
      const { rows: [c] } = await q('count_rider_load',
        `SELECT count(*)::int AS load FROM assignments
          WHERE rider_id = $1 AND state = 'ASSIGNED'`, [r.id]);
      scored.push({ ...r, load: c.load });
    }
    scored.sort((a, b) => a.load - b.load);
    return scored[0];
  }

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

  app.post('/api/dispatch/assign', async (req, res) => {
    const { order_id, customer_area } = req.body || {};
    if (!order_id) return res.status(400).json({ error: 'order_id required' });

    const rider = await pickRider(customer_area || null);
    if (!rider) {
      log.warn({ order_id, customer_area }, 'no rider available');
      return res.status(409).json({ error: 'no rider available in area', customer_area });
    }

    await q('insert_assignment',
      'INSERT INTO assignments (order_id, rider_id) VALUES ($1,$2)', [order_id, rider.id]);
    await q('update_state',
      `UPDATE orders SET state='ASSIGNED', updated_at=now() WHERE id=$1`, [order_id]);
    await q('append_event',
      `INSERT INTO order_events (order_id, from_state, to_state, actor)
       VALUES ($1,'ACCEPTED','ASSIGNED','dispatch')`, [order_id]);

    log.info({ order_id, rider_id: rider.id, rider: rider.name }, 'rider assigned');
    res.json({ order_id, rider: { id: rider.id, name: rider.name }, state: 'ASSIGNED' });
  });

  app.get('/api/dispatch/riders', async (_req, res) => {
    const { rows } = await q('riders_overview',
      `SELECT r.id, r.name, r.area, r.is_on_shift,
              count(a.id) FILTER (WHERE a.state='ASSIGNED') AS active
         FROM riders r LEFT JOIN assignments a ON a.rider_id = r.id
        GROUP BY r.id ORDER BY r.area, r.name`);
    res.json({ riders: rows });
  });

  const server = app.listen(PORT, () => log.info({ port: PORT }, `${SERVICE} listening`));
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
  return server;
};
