// Daig orders service - the application.
// Entry point for a customer order. Calls kitchen, which calls dispatch.
'use strict';

const express = require('express');
const { request } = require('undici');
const { registry, httpMetrics, ordersTotal } = require('../../_shared/metrics');
const { makePool } = require('../../_shared/db');
const { installGracefulShutdown } = require('../../_shared/shutdown');
const log = require('../../_shared/logger').build('orders');

const SERVICE = 'orders';

module.exports = function startServer(config) {
  const PORT = Number(process.env.PORT || 3001);
  const KITCHEN_URL = process.env.KITCHEN_URL || 'http://kitchen:3002';
  const { pool, q } = makePool(SERVICE, config.DATABASE_URL);

  log.info({ credential_source: config.source }, 'configuration resolved');

  const app = express();
  app.use(express.json({ limit: '64kb' }));
  app.use(httpMetrics(SERVICE));

  // --- probes ------------------------------------------------------------
  // liveness: is the process up? Deliberately does NOT touch the database - a
  // slow database must not cause the orchestrator to kill healthy instances,
  // which turns a degradation into an outage.
  app.get('/healthz', (_req, res) => res.json({ ok: true, service: SERVICE }));

  // readiness: can we actually serve? This one DOES check the database.
  app.get('/readyz', async (_req, res) => {
    try {
      await q('ready_check', 'SELECT 1');
      res.json({ ok: true, service: SERVICE, credentials: config.source });
    } catch (err) {
      log.error({ err: err.message }, 'readiness check failed');
      res.status(503).json({ ok: false, service: SERVICE, error: 'database unreachable' });
    }
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  // --- API ---------------------------------------------------------------
  app.get('/api/restaurants', async (_req, res) => {
    const { rows } = await q('list_restaurants',
      `SELECT r.id, r.name, r.area, r.prep_minutes, r.is_open,
              count(m.id) FILTER (WHERE m.is_available) AS available_items
         FROM restaurants r
         LEFT JOIN menu_items m ON m.restaurant_id = r.id
        GROUP BY r.id
        ORDER BY r.name`);
    res.json({ restaurants: rows });
  });

  app.get('/api/restaurants/:id/menu', async (req, res) => {
    const { rows } = await q('list_menu',
      `SELECT id, name, price_paisa, is_available
         FROM menu_items WHERE restaurant_id = $1 ORDER BY name`,
      [req.params.id]);
    res.json({ items: rows });
  });

  /**
   * Place an order. This is the request that produces the cross-service trace:
   *   orders -> postgres
   *   orders -> kitchen -> postgres
   *                     -> dispatch -> postgres
   */
  app.post('/api/orders', async (req, res) => {
    const { restaurant_id, customer_area, items } = req.body || {};
    if (!restaurant_id || !customer_area || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        error: 'restaurant_id, customer_area and a non-empty items array are required'
      });
    }

    // Load shedding hook for Day 4. Off by default.
    const dropRate = Number(process.env.CHAOS_DROP_RATE || 0);
    if (dropRate > 0 && Math.random() < dropRate) {
      log.warn({ drop_rate: dropRate }, 'shedding load');
      return res.status(503).json({ error: 'overloaded, retry' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows: [order] } = await client.query(
        `INSERT INTO orders (restaurant_id, customer_area, state)
         VALUES ($1, $2, 'PLACED') RETURNING id, state, created_at`,
        [restaurant_id, customer_area]
      );

      let total = 0;
      for (const it of items) {
        const { rows: [mi] } = await client.query(
          'SELECT id, price_paisa FROM menu_items WHERE id = $1 AND is_available',
          [it.menu_item_id]
        );
        if (!mi) {
          await client.query('ROLLBACK');
          return res.status(422).json({ error: `menu item unavailable: ${it.menu_item_id}` });
        }
        const qty = Math.max(1, Number(it.qty || 1));
        total += mi.price_paisa * qty;
        await client.query(
          `INSERT INTO order_items (order_id, menu_item_id, qty, price_paisa)
           VALUES ($1,$2,$3,$4)`,
          [order.id, mi.id, qty, mi.price_paisa]
        );
      }

      await client.query('UPDATE orders SET total_paisa=$1, updated_at=now() WHERE id=$2',
        [total, order.id]);
      await client.query(
        `INSERT INTO order_events (order_id, from_state, to_state, actor)
         VALUES ($1, NULL, 'PLACED', 'orders')`,
        [order.id]
      );
      await client.query('COMMIT');

      ordersTotal.inc({ state: 'PLACED' });
      log.info({ order_id: order.id, total_paisa: total }, 'order placed');

      // Downstream failure does not lose the order - it is already committed
      // and can be retried. Deciding what is durable before what is best-effort
      // is most of what transaction design is.
      let downstream = { ok: false };
      try {
        const r = await request(`${KITCHEN_URL}/api/kitchen/accept`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ order_id: order.id, customer_area }),
          headersTimeout: 10000,
          bodyTimeout: 10000
        });
        downstream = { ok: r.statusCode < 400, status: r.statusCode };
      } catch (err) {
        log.error({ err: err.message, order_id: order.id }, 'kitchen call failed');
        downstream = { ok: false, error: err.message };
      }

      res.status(201).json({ order_id: order.id, total_paisa: total, downstream });
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      log.error({ err: err.message }, 'order placement failed');
      res.status(500).json({ error: 'could not place order' });
    } finally {
      client.release();
    }
  });

  app.get('/api/orders/:id', async (req, res) => {
    const { rows } = await q('get_order',
      `SELECT o.*, json_agg(e.* ORDER BY e.created_at) AS events
         FROM orders o LEFT JOIN order_events e ON e.order_id = o.id
        WHERE o.id = $1 GROUP BY o.id`, [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  });

  // Training-only vulnerable routes. Off unless INSECURE_MODE=true, and the
  // module itself exits 78 if NODE_ENV=production.
  if (process.env.INSECURE_MODE === 'true') {
    require('./insecure').mountInsecureRoutes(app, { q, log });
  }

  const server = app.listen(PORT, () => log.info({ port: PORT }, `${SERVICE} listening`));
  installGracefulShutdown({ server, pool, log });
  return server;
};
