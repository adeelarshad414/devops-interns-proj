// Ordered, bounded graceful shutdown - shared by every service.
//
// The sequence matters. On SIGTERM (a rollout, a scale-down, a `docker stop`)
// the orchestrator gives us a grace period, then SIGKILLs. In that window we:
//   1. stop accepting new connections and let in-flight requests finish
//   2. close the database pool
//   3. flush telemetry so the last spans are exported
//   4. exit 0
//
// One handler owns exit. Previously telemetry.js registered its OWN SIGTERM
// handler that called sdk.shutdown().finally(process.exit(0)) - it usually won
// the race and killed requests mid-flight that this drain exists to protect.
//
// The forced-exit timer is the safety net: if a slow client keeps a connection
// open, we do not wait for SIGKILL - we exit non-zero after `timeoutMs` so the
// orchestrator records an unclean stop instead of a silent hang.
'use strict';

const { stopTelemetry } = require('./telemetry');

function installGracefulShutdown({ server, pool, log, timeoutMs }) {
  const budget = Number(timeoutMs || process.env.SHUTDOWN_TIMEOUT_MS || 8000);
  let shuttingDown = false;

  const shutdown = async (signal) => {
    if (shuttingDown) return;            // a second signal must not restart the sequence
    shuttingDown = true;
    log.info({ signal, timeout_ms: budget }, 'shutdown requested, draining');

    const forced = setTimeout(() => {
      log.error({ timeout_ms: budget }, 'drain exceeded budget, forcing exit');
      process.exit(1);
    }, budget);
    forced.unref();                      // do not keep the loop alive just for the timer

    try {
      await new Promise((resolve) => server.close(resolve));
      if (pool) await pool.end();
      await stopTelemetry();
      log.info({}, 'drained cleanly');
      process.exit(0);
    } catch (err) {
      log.error({ err: err.message }, 'error during shutdown');
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

module.exports = { installGracefulShutdown };
