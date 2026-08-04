// Daig orders service - TIER 2 - entry point.
//
// This file does exactly two things: start telemetry, and resolve credentials
// before anything opens a port. The application itself is in server.js.
//
// The split exists because credential resolution is asynchronous - it may
// involve a network round trip to OpenBao - and a CommonJS module cannot await
// at the top level. Separating bootstrap from application is also just better
// structure, so the constraint pushed us somewhere we should have been anyway.
'use strict';

require('../../_shared/telemetry').startTelemetry('orders');

const { bootstrap } = require('../../_shared/secrets');
const startServer = require('./server');

bootstrap('orders', { required: ['DATABASE_URL'] })
  .then((config) => startServer(config))
  .catch((err) => {
    process.stderr.write(JSON.stringify({
      level: 'fatal', service: 'orders', msg: 'bootstrap failed', error: err.message
    }) + '\n');
    process.exit(1);
  });
