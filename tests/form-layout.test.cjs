const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const L = load('FormLayout.js');

const geom = { cellW: 170, cellH: 120, padding: 12, gap: 8, editInset: 14, editGap: 10, editRow: 44, editNote: 28, editChipH: 28, editStageH: 104, editStagePad: 12, editFormMinW: 640 };
const pomodoro = ['number', 'number', 'number', 'number', 'bool', 'note'];

test('one arrangement for every span: the widget at real size on a full-width stage, fields in two columns', () => {
    for (const [span, page] of [['1x1', 'small'], ['2x1', 'small'], ['4x1', 'wide'], ['2x1', 'tall']]) {
        const p = j(L.plan(pomodoro, span, page, geom));
        assert.deepEqual(p.cols, [[0, 1, 2], [3, 4, 5]]);
        assert.equal(p.stageH, 128);
        assert.ok(p.box.h <= 104);
        assert.equal(p.contentH, 128 + 10 + 44 + 132 + 10 + 28);
    }
});

test('the panel width follows the span: a 656 px 4x1 fits, the others keep the two-column minimum', () => {
    assert.equal(L.plan(pomodoro, '4x1', 'wide', geom).width, 656 + 24 + 28);
    assert.equal(L.plan(pomodoro, '1x1', 'small', geom).width, 640);
    assert.equal(L.plan(pomodoro, '2x1', 'small', geom).width, 640);
});

test('the note counts at its own height, an odd field goes left', () => {
    const p = j(L.plan(['number', 'number', 'note'], '1x1', 'small', geom));
    assert.deepEqual(p.cols, [[0, 1], [2]]);
    assert.equal(p.contentH, 128 + 10 + 44 + 88 + 10 + 28);
});
