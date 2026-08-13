#!/usr/bin/env node
// Reproduces Daig's daily traffic shape, compressed into a few minutes.
// Zero dependencies on purpose - it must run before anyone has installed
// anything, including on a laptop with no network.
//
//   node load/iftar-spike.js                 # full curve, ~3 minutes
//   PROFILE=spike node load/iftar-spike.js   # peak only, for Day 4
//   PROFILE=flat  node load/iftar-spike.js   # steady baseline
'use strict';

const BASE = process.env.TARGET || 'http://localhost:3001';
const PROFILE = process.env.PROFILE || 'curve';

// Orders per second at each step. The real curve from the deck's chart,
// scaled down so a laptop survives it.
const CURVES = {
  curve: [2, 3, 2, 3, 4, 8, 22, 60, 120, 45, 14, 6],
  spike: [120, 120, 120, 120],
  flat:  [4, 4, 4, 4, 4, 4]
};
const STEP_MS = Number(process.env.STEP_MS || 15000);
const AREAS = ['Gulberg', 'Saddar', 'Tariq Road', 'Burns Road', 'Do Darya', 'Lakshmi Chowk'];

const stats = { sent: 0, ok: 0, failed: 0, shed: 0, latencies: [] };

async function getJson(path) {
  const res = await fetch(BASE + path);
  if (!res.ok) throw new Error(`${path} -> ${res.status}`);
  return res.json();
}

async function placeOrder(catalog) {
  const pick = catalog[Math.floor(Math.random() * catalog.length)];
  if (!pick || !pick.items.length) return;
  const item = pick.items[Math.floor(Math.random() * pick.items.length)];

  const started = Date.now();
  stats.sent++;
  try {
    const res = await fetch(`${BASE}/api/orders`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        restaurant_id: pick.id,
        customer_area: AREAS[Math.floor(Math.random() * AREAS.length)],
        items: [{ menu_item_id: item.id, qty: 1 + Math.floor(Math.random() * 3) }]
      })
    });
    stats.latencies.push(Date.now() - started);
    if (res.status === 503) stats.shed++;
    else if (res.ok) stats.ok++;
    else stats.failed++;
  } catch {
    stats.failed++;
    stats.latencies.push(Date.now() - started);
  }
}

function percentile(arr, p) {
  if (!arr.length) return 0;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
}

function report(label) {
  const l = stats.latencies;
  console.log(
    `[${label}] sent=${stats.sent} ok=${stats.ok} shed=${stats.shed} ` +
    `failed=${stats.failed} p50=${percentile(l, 50)}ms p95=${percentile(l, 95)}ms ` +
    `p99=${percentile(l, 99)}ms`
  );
}

(async () => {
  console.log(`target ${BASE}, profile "${PROFILE}"`);

  const { restaurants } = await getJson('/api/restaurants');
  if (!restaurants.length) {
    console.error('No restaurants. Run `make seed` first.');
    process.exit(1);
  }

  const catalog = [];
  for (const r of restaurants) {
    const { items } = await getJson(`/api/restaurants/${r.id}/menu`);
    catalog.push({ id: r.id, name: r.name, items: items.filter(i => i.is_available) });
  }
  const usable = catalog.filter(c => c.items.length);
  if (!usable.length) {
    console.error('Restaurants exist but have no menu items. Run `make seed`.');
    process.exit(1);
  }
  console.log(`catalog: ${usable.length} restaurants\n`);

  const curve = CURVES[PROFILE] || CURVES.curve;
  for (let step = 0; step < curve.length; step++) {
    const rps = curve[step];
    const total = Math.round(rps * (STEP_MS / 1000));
    const gap = Math.max(1, Math.floor(STEP_MS / Math.max(total, 1)));

    process.stdout.write(`step ${step + 1}/${curve.length} - ${rps} orders/s ... `);
    const before = { ...stats };
    const inflight = [];
    for (let i = 0; i < total; i++) {
      inflight.push(placeOrder(usable));
      await new Promise(r => setTimeout(r, gap));
    }
    await Promise.allSettled(inflight);
    const okDelta = stats.ok - before.ok;
    console.log(`${okDelta}/${total} accepted`);
  }

  console.log('');
  report('total');

  const errorRate = stats.sent ? (stats.failed + stats.shed) / stats.sent : 0;
  console.log(`\nerror rate ${(errorRate * 100).toFixed(2)}%  (SLO allows 0.10%)`);
  if (errorRate > 0.001) {
    console.log('You just burned error budget. That is the exercise.');
  }
})().catch(e => { console.error(e.message); process.exit(1); });
