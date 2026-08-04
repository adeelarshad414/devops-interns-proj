// Daig dispatch service - entry point. See services/orders/src/index.js for why
// bootstrap and application are separate files.
'use strict';

require('../../_shared/telemetry').startTelemetry('dispatch');

const { bootstrap } = require('../../_shared/secrets');
const startServer = require('./server');

bootstrap('dispatch', { required: ['DATABASE_URL'] })
  .then((config) => startServer(config))
  .catch((err) => {
    process.stderr.write(JSON.stringify({
      level: 'fatal', service: 'dispatch', msg: 'bootstrap failed', error: err.message
    }) + '\n');
    process.exit(1);
  });
