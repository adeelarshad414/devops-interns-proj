// Tier 1. No framework, no build step - see services/web/Dockerfile for why.
'use strict';

const $ = (id) => document.getElementById(id);

async function json(url, opts) {
  const res = await fetch(url, opts);
  const body = await res.text();
  try { return { status: res.status, data: JSON.parse(body) }; }
  catch { return { status: res.status, data: body }; }
}

async function loadTiers() {
  const probes = [
    ['web',      '/healthz'],
    ['orders',   '/api/orders/__probe__'],   // 404 proves the route is wired
    ['kitchen',  '/api/kitchen/__probe__'],
    ['dispatch', '/api/dispatch/riders']
  ];
  const out = [];
  for (const [name, url] of probes) {
    let ok = false, note = '';
    try {
      const r = await fetch(url);
      // Anything that is not a gateway error means the tier answered.
      ok = r.status < 500;
      note = `HTTP ${r.status}`;
    } catch (e) { note = e.message; }
    out.push(`<div class="card">
      <div class="name">${name} <span class="pill ${ok ? 'ok' : 'bad'}">${ok ? 'UP' : 'DOWN'}</span></div>
      <div class="meta">${note}</div></div>`);
  }
  $('tiers').innerHTML = out.join('');
}

async function loadRestaurants() {
  const { data } = await json('/api/restaurants');
  const list = (data && data.restaurants) || [];
  if (!list.length) {
    $('restaurants').innerHTML = '<div class="card">No restaurants. Run <code>make seed</code>.</div>';
    return;
  }
  $('restaurants').innerHTML = list.map(r => `
    <div class="card">
      <div class="name">${r.name} <span class="pill ${r.is_open ? 'ok' : 'bad'}">${r.is_open ? 'OPEN' : 'CLOSED'}</span></div>
      <div class="meta">${r.area} · ${r.prep_minutes} min prep · ${r.available_items} items</div>
    </div>`).join('');

  $('restaurant').innerHTML = list
    .map(r => `<option value="${r.id}">${r.name}</option>`).join('');
}

async function placeOrder() {
  const restaurantId = $('restaurant').value;
  const area = $('area').value;
  $('result').textContent = 'placing…';

  const menu = await json(`/api/restaurants/${restaurantId}/menu`);
  const items = ((menu.data && menu.data.items) || [])
    .filter(i => i.is_available).slice(0, 2)
    .map(i => ({ menu_item_id: i.id, qty: 1 }));

  if (!items.length) {
    $('result').textContent = 'That restaurant has no available items. Run make seed.';
    return;
  }

  const res = await json('/api/orders', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ restaurant_id: restaurantId, customer_area: area, items })
  });
  $('result').textContent = `HTTP ${res.status}\n` + JSON.stringify(res.data, null, 2);
}

$('place').addEventListener('click', placeOrder);
loadTiers();
loadRestaurants();
setInterval(loadTiers, 15000);
