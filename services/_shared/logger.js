// Structured JSON logs to stdout. Promtail ships them to Loki.
// trace_id is injected so a log line can be pivoted straight to its trace.
'use strict';
const pino = require('pino');
const { trace } = require('@opentelemetry/api');

function build(service) {
  const base = pino({
    level: process.env.LOG_LEVEL || 'info',
    base: { service },
    timestamp: pino.stdTimeFunctions.isoTime,
    formatters: { level: (label) => ({ level: label }) }
  });

  // Wrap so every line carries the active trace and span id.
  const withTrace = (fn) => (obj, msg) => {
    const span = trace.getActiveSpan();
    const ctx = span ? span.spanContext() : null;
    const extra = ctx ? { trace_id: ctx.traceId, span_id: ctx.spanId } : {};
    if (typeof obj === 'string') return fn.call(base, extra, obj);
    return fn.call(base, { ...obj, ...extra }, msg);
  };

  return {
    info:  withTrace(base.info),
    warn:  withTrace(base.warn),
    error: withTrace(base.error),
    debug: withTrace(base.debug),
    raw: base
  };
}

module.exports = { build };
