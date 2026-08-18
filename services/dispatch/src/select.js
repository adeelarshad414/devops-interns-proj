// Rider selection - pure, no I/O, so it is unit-testable without a database.
// The DB-bound lookup (and the Day 4 N+1 defect) lives in server.js; the actual
// CHOICE of who to assign is just "least loaded", extracted here.
'use strict';

// Given riders each carrying a numeric `load`, return the least loaded. Ties are
// broken by input order (the first least-loaded wins), which keeps the SQL fast
// path and this JS slow path behaviourally identical.
function pickLeastLoaded(riders) {
  if (!riders || riders.length === 0) return null;
  return riders.reduce((best, r) => (r.load < best.load ? r : best));
}

module.exports = { pickLeastLoaded };
