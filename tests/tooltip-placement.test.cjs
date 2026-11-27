const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const P = load('TooltipPlacement.js');

const win = { w: 400, h: 300 };
const tip = { w: 100, h: 26 };
const at = (x, y, w = 24, h = 24) => ({ x, y, w, h });

test('with room above it goes above, centred on the owner', () => {
    assert.deepEqual(j(P.place(at(100, 100), tip, win, 4, 3)), { x: -38, y: -29, above: true });
});

test('at the top edge it flips below the owner', () => {
    const r = P.place(at(100, 6), tip, win, 4, 3);
    assert.equal(r.above, false);
    assert.equal(r.y, 27);
});

test('the flipped tooltip stays inside the window', () => {
    const owner = at(150, 6);
    const r = P.place(owner, tip, win, 4, 3);
    assert.ok(owner.y + r.y >= 4);
    assert.ok(owner.y + r.y + tip.h <= win.h - 4);
});

test('an above tooltip keeps its margin from the top', () => {
    const owner = at(100, 40);
    const r = P.place(owner, tip, win, 4, 3);
    assert.equal(r.above, true);
    assert.ok(owner.y + r.y >= 4);
    assert.equal(P.place(at(100, 32), tip, win, 4, 3).above, false);
});

test('it slides in from the left and right edges', () => {
    const left = P.place(at(2, 100), tip, win, 4, 3);
    assert.equal(2 + left.x, 4);
    const right = P.place(at(380, 100), tip, win, 4, 3);
    assert.equal(380 + right.x + tip.w, win.w - 4);
});

test('with room on neither side it takes the side with more room', () => {
    const small = { w: 400, h: 60 };
    assert.equal(P.place(at(100, 12, 24, 24), { w: 100, h: 40 }, small, 4, 3).above, false);
    assert.equal(P.place(at(100, 24, 24, 24), { w: 100, h: 40 }, small, 4, 3).above, true);
});

test('an unknown window size keeps the old placement', () => {
    assert.deepEqual(j(P.place(at(100, 6), tip, { w: 0, h: 0 }, 4, 3)), { x: -38, y: -29, above: true });
});
