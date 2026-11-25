const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const D = load('PomodoroDnd.js');

const MIN = 60000;
const NOW = 1e12;
const ops = r => j(r.effects).map(e => e.op);

test('no DND yet: Kove sets it to the phase end and owns it', () => {
    const r = D.engage(D.idle(), null, NOW + 25 * MIN, NOW);
    assert.deepEqual(j(r), { state: { ours: true, until: NOW + 25 * MIN }, effects: [{ op: 'set', until: NOW + 25 * MIN }] });
    assert.equal(ops(D.engage(D.idle(), NOW - 1000, NOW + 25 * MIN, NOW)).join(), 'set');
});

test('a DND that ends sooner is extended; one that lasts longer or never ends is left alone', () => {
    assert.equal(ops(D.engage(D.idle(), NOW + 10 * MIN, NOW + 25 * MIN, NOW)).join(), 'set');
    const later = D.engage(D.idle(), NOW + 60 * MIN, NOW + 25 * MIN, NOW);
    assert.deepEqual(j(later), { state: { ours: false }, effects: [] });
    assert.equal(D.engage(D.idle(), new Date('9999-12-31').getTime(), NOW + 25 * MIN, NOW).effects.length, 0);
});

test('releasing clears only what Kove set and Plasma still holds', () => {
    const ours = { ours: true, until: NOW + 25 * MIN };
    assert.equal(ops(D.release(ours, NOW + 25 * MIN, NOW + 5 * MIN, false)).join(), 'clear');
    assert.equal(ops(D.release(ours, NOW + 99 * MIN, NOW + 5 * MIN, false)).join(), '');
    assert.equal(ops(D.release(ours, null, NOW, false)).join(), '');
    assert.equal(ops(D.release(D.idle(), NOW + 25 * MIN, NOW, false)).join(), '');
    assert.deepEqual(j(D.release(ours, NOW + 25 * MIN, NOW, false).state), { ours: false });
});

test('at a phase end the clear comes before the alert, so the alert is not silenced', () => {
    const ours = { ours: true, until: NOW + 25 * MIN };
    assert.equal(ops(D.release(ours, NOW + 25 * MIN, NOW + 25 * MIN - 500, true)).join(), 'clear,alert');
    assert.equal(ops(D.release(D.idle(), NOW + 90 * MIN, NOW, true)).join(), 'alert');
});
