// Prometheus metrics. Deliberately small: four series that matter.
'use strict';
const client = require('prom-client');

const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

const httpDuration = new client.Histogram({
  name: 'daig_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['service', 'method', 'route', 'status'],
  // Buckets chosen around the SLO, not around round numbers.
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10],
  registers: [registry]
});

const ordersTotal = new client.Counter({
  name: 'daig_orders_total',
  help: 'Orders by terminal state',
  labelNames: ['state'],
  registers: [registry]
});

const dbQueryDuration = new client.Histogram({
  name: 'daig_db_query_duration_seconds',
  help: 'Database query duration in seconds',
  labelNames: ['service', 'op'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [registry]
});

const inflight = new client.Gauge({
  name: 'daig_http_inflight_requests',
  help: 'In-flight HTTP requests',
  labelNames: ['service'],
  registers: [registry]
});

/** Express middleware. Records duration and in-flight count. */
function httpMetrics(service) {
  return (req, res, next) => {
    const path = (req.path || '').split('?')[0];
    if (['/healthz', '/readyz', '/metrics'].includes(path)) return next();

    inflight.inc({ service });
    const end = httpDuration.startTimer({ service, method: req.method });
    res.on('finish', () => {
      inflight.dec({ service });
      // req.route is undefined on 404 - fall back to the raw path so we do not
      // silently drop the metric, but keep cardinality sane.
      const route = (req.route && req.route.path) || 'unmatched';
      end({ route, status: String(res.statusCode) });
    });
    next();
  };
}

module.exports = { registry, httpMetrics, httpDuration, ordersTotal, dbQueryDuration, inflight };
