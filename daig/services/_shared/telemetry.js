// OpenTelemetry bootstrap. MUST be required before anything else.
// Traces -> OTLP/HTTP -> Collector -> Tempo
// Metrics -> Prometheus scrape on /metrics (via prom-client, see metrics.js)
// Logs    -> stdout JSON -> Promtail -> Loki
'use strict';

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { resourceFromAttributes } = require('@opentelemetry/resources');
const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION
} = require('@opentelemetry/semantic-conventions');

function startTelemetry(serviceName) {
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4318';

  const sdk = new NodeSDK({
    resource: resourceFromAttributes({
      [ATTR_SERVICE_NAME]: serviceName,
      [ATTR_SERVICE_VERSION]: process.env.SERVICE_VERSION || '0.1.0',
      'service.namespace': process.env.OTEL_SERVICE_NAMESPACE || 'daig',
      'deployment.environment': process.env.NODE_ENV || 'development'
    }),
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
    instrumentations: [
      getNodeAutoInstrumentations({
        // Health probes generate enormous trace volume and teach nothing.
        '@opentelemetry/instrumentation-http': {
          ignoreIncomingRequestHook: (req) =>
            ['/healthz', '/readyz', '/metrics'].includes((req.url || '').split('?')[0])
        },
        '@opentelemetry/instrumentation-fs': { enabled: false }
      })
    ]
  });

  sdk.start();
  console.log(JSON.stringify({
    level: 'info', msg: 'telemetry started', service: serviceName, endpoint
  }));

  const shutdown = () => sdk.shutdown()
    .catch(e => console.error('otel shutdown failed', e))
    .finally(() => process.exit(0));
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

module.exports = { startTelemetry };
