const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const F = load('PageFit.js');

test('report marks the placements a page cannot take and keeps the rest in place', () => {
    const r = j(F.report('small', ['1x1', '1x1', '1x1']));
    assert.deepEqual(r.map(x => x.fits), [true, true, false]);
    assert.deepEqual(r.slice(0, 2).map(x => [x.col, x.row]), [[0, 0], [1, 0]]);
    assert.deepEqual(j(F.report('small', ['4x1', '1x1'])).map(x => x.fits), [false, true]);
    assert.deepEqual(j(F.report('tall', [])), []);
});

test('switching the page type is blocked, with the culprits, and never removes anything', () => {
    assert.deepEqual(j(F.canSwitch('wide', ['2x1', '1x1', '1x1'])), { ok: true, blocked: [] });
    assert.deepEqual(j(F.canSwitch('small', ['2x1', '1x1', '1x1'])), { ok: false, blocked: [1, 2] });
    assert.deepEqual(j(F.canSwitch('small', ['4x1'])), { ok: false, blocked: [0] });
    assert.deepEqual(j(F.canSwitch('tall', [])), { ok: true, blocked: [] });
});

test('empty cells carry the index a widget added there would take', () => {
    assert.deepEqual(j(F.emptyCells('small', ['1x1'])), [{ col: 1, row: 0, index: 1 }]);
    assert.deepEqual(j(F.emptyCells('small', [])), [{ col: 0, row: 0, index: 0 }, { col: 1, row: 0, index: 0 }]);
    assert.deepEqual(j(F.emptyCells('small', ['1x1', '1x1'])), []);
    // a 2x1 wraps below the 1x1, leaving a hole beside it
    assert.deepEqual(j(F.emptyCells('tall', ['1x1', '2x1'])), [{ col: 1, row: 0, index: 1 }]);
    assert.deepEqual(j(F.emptyCells('nope', [])), []);
});

test('spansFitting asks about the insertion index, not just the free space', () => {
    assert.deepEqual(j(F.spansFitting('small', ['1x1'], 1, ['1x1', '2x1'])), ['1x1']);
    assert.deepEqual(j(F.spansFitting('tall', ['1x1'], 1, ['1x1', '2x1'])), ['1x1', '2x1']);
    assert.deepEqual(j(F.spansFitting('small', ['1x1', '1x1'], 0, ['1x1'])), []);
});

test('move reflows the list, and refuses an order that no longer fits', () => {
    assert.deepEqual(j(F.move('wide', ['2x1', '1x1', '1x1'], 0, 2)), ['1x1', '1x1', '2x1']);
    assert.equal(F.move('small', ['1x1', '1x1'], 0, 0), null);
    assert.equal(F.move('small', ['1x1', '1x1'], 0, 5), null);
    assert.deepEqual(j(F.move('small', ['1x1', '1x1'], 0, 1)), ['1x1', '1x1']);
    assert.equal(F.move('tall', ['2x1', '1x1'], 1, 0) === null, false);
    assert.equal(F.move('small', ['1x1', '2x1'], 1, 0), null); // too tall already: the list never fit
});
