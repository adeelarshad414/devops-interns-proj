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

// One SDK per process, held so the server's shutdown sequence can flush it in
// order (after the HTTP server has drained), instead of a second SIGTERM
// handler racing the drain and calling process.exit() out from under it.
let sdkRef = null;

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
  sdkRef = sdk;
  console.log(JSON.stringify({
    level: 'info', msg: 'telemetry started', service: serviceName, endpoint
  }));
}

// Flush and stop the SDK. The server's graceful-shutdown sequence calls this
// AFTER the HTTP server has drained, so the last spans of in-flight requests
// are exported before the process exits. Never calls process.exit itself -
// exactly one place owns exit (see _shared/shutdown.js).
async function stopTelemetry() {
  if (!sdkRef) return;
  try {
    await sdkRef.shutdown();
  } catch (e) {
    console.error('otel shutdown failed', e);
  } finally {
    sdkRef = null;
  }
}

module.exports = { startTelemetry, stopTelemetry };
