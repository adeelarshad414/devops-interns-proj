// Liveness must be answerable without a database - that is the whole reason
// /healthz and /readyz are separate. This boots the real server on an ephemeral
// port and proves /healthz is 200 even though the DATABASE_URL points nowhere.
'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');

process.env.PORT = '0'; // ephemeral port - no clashes between test files
const startServer = require('../src/server');

let server;
before(async () => {
  server = startServer({ source: 'test', DATABASE_URL: 'postgresql://u:p@127.0.0.1:5432/none' });
  if (!server.listening) await new Promise((r) => server.once('listening', r));
});
after(() => new Promise((r) => server.close(r)));

function get(path) {
  return new Promise((resolve, reject) => {
    const { port } = server.address();
    http.get({ host: '127.0.0.1', port, path }, (res) => {
      let body = '';
      res.on('data', (d) => (body += d));
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });
}

test('liveness /healthz is 200 and does not touch the database', async () => {
  const res = await get('/healthz');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(JSON.parse(res.body).ok, true);
});
