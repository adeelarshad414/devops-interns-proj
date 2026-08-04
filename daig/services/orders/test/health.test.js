// Minimal tests. The point on Day 4 is that CI can BLOCK a deploy,
// so there must be something real for it to run.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert');
const { required, EX_CONFIG } = require('../../_shared/guard');

test('EX_CONFIG is 78', () => {
  assert.strictEqual(EX_CONFIG, 78);
});

test('required() returns a present value', () => {
  process.env.__DAIG_TEST__ = 'present';
  assert.strictEqual(required('__DAIG_TEST__'), 'present');
  delete process.env.__DAIG_TEST__;
});

test('paisa arithmetic uses integers only', () => {
  // Money in floats is how you end up 1 paisa short a million times.
  const total = [12500, 45000, 8000].reduce((a, b) => a + b, 0);
  assert.strictEqual(total, 65500);
  assert.ok(Number.isInteger(total));
});
