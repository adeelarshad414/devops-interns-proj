// Real unit tests for kitchen's surge pricing. The Day 4 point stands: CI can
// only BLOCK a deploy if there is something real for it to run.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert');
const { computeSurgeScore } = require('../src/surge');

test('surge is 1.0 when nothing is open', () => {
  assert.strictEqual(computeSurgeScore([]), 1);
});

test('surge scales with the busiest area and caps at 2.5', () => {
  const open = Array.from({ length: 50 }, () => ({ customer_area: 'DHA' }));
  // 1 + min(50/25, 1.5) = 1 + 1.5 = 2.5, the cap.
  assert.strictEqual(computeSurgeScore(open), 2.5);
});

test('the O(n^2) chaos path returns the SAME score as the fast path', () => {
  const open = [
    { customer_area: 'DHA' }, { customer_area: 'DHA' },
    { customer_area: 'Clifton' }, { customer_area: 'DHA' }
  ];
  delete process.env.CHAOS_HOT_SURGE_LOOP;
  const fast = computeSurgeScore(open);
  process.env.CHAOS_HOT_SURGE_LOOP = 'true';
  const slow = computeSurgeScore(open);
  delete process.env.CHAOS_HOT_SURGE_LOOP;
  // The defect is a performance bug, not a correctness one - the score is equal.
  assert.strictEqual(fast, slow);
});
