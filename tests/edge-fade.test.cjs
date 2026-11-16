const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({ Math });
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/EdgeFade.js'), 'utf8').replace('.pragma library', ''), ctx);
const E = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));

test('content that fits has no fade at either edge', () => {
    assert.deepEqual(j(E.strengths(0, 300, 400, 0, 28)), { top: 0, bottom: 0 });
});

test('at the top only the bottom fades; at the bottom only the top fades', () => {
    assert.deepEqual(j(E.strengths(0, 1000, 400, 6, 28)), { top: 0, bottom: 1 });
    assert.deepEqual(j(E.strengths(606, 1000, 400, 6, 28)), { top: 1, bottom: 0 });
});

test('the fade ramps in over the fade distance instead of popping', () => {
    assert.equal(E.strengths(14, 1000, 400, 6, 28).top, 0.5);
    assert.equal(E.strengths(606 - 7, 1000, 400, 6, 28).bottom, 0.25);
});

test('stops stay ordered even in a view shorter than two fades', () => {
    const s = E.stops(400, 28);
    assert.ok(Math.abs(s.inner0 - 0.07) < 1e-9 && Math.abs(s.inner1 - 0.93) < 1e-9);
    assert.deepEqual(j(E.stops(40, 28)), { inner0: 0.5, inner1: 0.5 });
    assert.deepEqual(j(E.stops(0, 28)), { inner0: 0, inner1: 1 });
});

test('mix interpolates and clamps', () => {
    assert.deepEqual(j(E.mix([0, 0, 0], [1, 0.5, 0], 0.5)), [0.5, 0.25, 0]);
    assert.deepEqual(j(E.mix([0, 0, 0], [1, 1, 1], 2)), [1, 1, 1]);
});
