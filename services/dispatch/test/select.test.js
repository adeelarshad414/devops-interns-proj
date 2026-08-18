// Real unit test for dispatch's rider selection. Pure, no DB - the Day 4 point
// stands: CI can only BLOCK a deploy if there is something real for it to run.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert');
const { pickLeastLoaded } = require('../src/select');

test('returns null when there are no riders', () => {
  assert.strictEqual(pickLeastLoaded([]), null);
  assert.strictEqual(pickLeastLoaded(undefined), null);
});

test('picks the least-loaded rider', () => {
  const r = pickLeastLoaded([{ id: 1, load: 3 }, { id: 2, load: 1 }, { id: 3, load: 2 }]);
  assert.strictEqual(r.id, 2);
});

test('breaks ties by input order, matching the SQL fast path', () => {
  const r = pickLeastLoaded([{ id: 1, load: 2 }, { id: 2, load: 2 }]);
  assert.strictEqual(r.id, 1);
});
