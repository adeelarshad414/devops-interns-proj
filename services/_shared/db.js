// Postgres pool with query timing. One pool per process.
'use strict';
const { Pool } = require('pg');
const { dbQueryDuration } = require('./metrics');

function makePool(service, connectionString) {
  const pool = new Pool({
    connectionString,
    max: Number(process.env.PG_POOL_MAX || 10),
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000
  });

  pool.on('error', (err) => {
    console.error(JSON.stringify({ level: 'error', msg: 'idle client error', err: err.message }));
  });

  /** Timed query. `op` is a low-cardinality label, never the SQL itself. */
  async function q(op, sql, params) {
    const end = dbQueryDuration.startTimer({ service, op });
    try {
      return await pool.query(sql, params);
    } finally {
      end();
    }
  }

  return { pool, q };
}

module.exports = { makePool };
