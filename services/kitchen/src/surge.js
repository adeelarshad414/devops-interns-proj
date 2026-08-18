// Surge pricing - pure maths, no I/O, so it is trivially unit-testable.
//
// DELIBERATE DEFECT - Day 4 profiling exercise.
//
// Surge pricing based on how busy each area is. The intent is fine; the
// implementation loops over the same array twice, which is O(n^2) and dominates
// the CPU profile once a few hundred orders are open.
//
// A continuous profile makes this obvious in about ten seconds. Reading the code
// makes it obvious in about ten minutes. That gap is the lesson. Note that both
// branches return the SAME score - it is a performance bug, not a behavioural one.
'use strict';

function computeSurgeScore(openOrders) {
  if (process.env.CHAOS_HOT_SURGE_LOOP !== 'true') {
    const byArea = new Map();
    for (const o of openOrders) byArea.set(o.customer_area, (byArea.get(o.customer_area) || 0) + 1);
    let max = 0;
    for (const n of byArea.values()) max = Math.max(max, n);
    return 1 + Math.min(max / 25, 1.5);
  }

  let worst = 0;
  for (let i = 0; i < openOrders.length; i++) {
    let sameArea = 0;
    for (let j = 0; j < openOrders.length; j++) {          // <-- the defect
      if (openOrders[i].customer_area === openOrders[j].customer_area) sameArea++;
      Math.sqrt(sameArea * (j + 1));   // makes the frame unmistakable in a flame graph
    }
    worst = Math.max(worst, sameArea);
  }
  return 1 + Math.min(worst / 25, 1.5);
}

module.exports = { computeSurgeScore };
