const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load } = require('./logic-loader.cjs');
const S = load('Stepper.js');

test('a step moves by the field step and stops at the limits', () => {
    assert.equal(S.next(25, 1, 5, 5, 90), 30);
    assert.equal(S.next(25, -1, 5, 5, 90), 20);
    assert.equal(S.next(90, 1, 5, 5, 90), 90);
    assert.equal(S.next(5, -1, 5, 5, 90), 5);
});

test('the repeat interval ramps from slow to fast and stays fast', () => {
    assert.equal(S.interval(0, 160, 45, 12), 160);
    assert.equal(S.interval(6, 160, 45, 12), 103);
    assert.equal(S.interval(12, 160, 45, 12), 45);
    assert.equal(S.interval(99, 160, 45, 12), 45);
});
