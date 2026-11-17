const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const S = load('Silhouette.js');
const cell = { w: 170, h: 120 };
const box = { w: 44, h: 28 };

test('the drawing keeps the page proportions, centred in the box', () => {
    const s = j(S.rects('small', ['1x1', '1x1'], box, cell, 2));
    assert.ok(Math.abs(s.w / s.h - 340 / 120) < 1e-9);
    assert.ok(s.w <= box.w + 1e-9 && s.h <= box.h + 1e-9);
    assert.ok(Math.abs(s.x * 2 + s.w - box.w) < 1e-9);
    assert.equal(s.rects.length, 2);
    assert.ok(s.rects[1].x > s.rects[0].x + s.rects[0].w - 1e-9);
});

test('a Tall page draws two rows; a 2x1 spans the width; widgets that do not fit are left out', () => {
    const t = j(S.rects('tall', ['2x1', '1x1', '1x1'], box, cell, 2));
    assert.equal(t.rects.length, 3);
    assert.ok(Math.abs(t.rects[0].w - (t.w - 2)) < 1e-9);
    assert.ok(t.rects[1].y > t.rects[0].y);
    assert.equal(j(S.rects('small', ['1x1', '1x1', '1x1'], box, cell, 2)).rects.length, 2);
});

test('a blank preset draws the empty page, and an unknown page draws nothing', () => {
    assert.deepEqual(j(S.rects('wide', [], box, cell, 2)).rects, []);
    assert.equal(j(S.rects('wide', [], box, cell, 2)).w > 0, true);
    assert.deepEqual(j(S.rects('nope', ['1x1'], box, cell, 2)).rects, []);
});

test('rectangles stay inside the drawing', () => {
    for (const page of ['small', 'wide', 'tall']) {
        const s = j(S.rects(page, ['1x1', '1x1', '2x1'], box, cell, 2));
        for (const r of s.rects) assert.ok(r.x >= 0 && r.y >= 0 && r.x + r.w <= s.w + 1e-9 && r.y + r.h <= s.h + 1e-9);
    }
});
