const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/Presets.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const registry = { byId: { clock: { spans: ['1x1'] }, weather: { spans: ['1x1', '2x1', '4x1'] } } };
const p = (page, spans, extra) => Object.assign({ id: 'p' + page + spans.length, name: 'N', page, placements: spans.map(s => ({ widget: s === '1x1' ? 'clock' : 'weather', span: s })) }, extra);
const blob = (...presets) => JSON.stringify({ format: 1, presets });

test('packing is row-major and a span too wide for the page fails', () => {
    assert.deepEqual(j(ctx.pack('small', ['1x1', '1x1'])), [{ col: 0, row: 0, cols: 1 }, { col: 1, row: 0, cols: 1 }]);
    assert.deepEqual(j(ctx.pack('tall', ['2x1', '1x1', '1x1'])), [{ col: 0, row: 0, cols: 2 }, { col: 0, row: 1, cols: 1 }, { col: 1, row: 1, cols: 1 }]);
    assert.deepEqual(j(ctx.pack('wide', ['4x1'])), [{ col: 0, row: 0, cols: 4 }]);
    assert.deepEqual(j(ctx.pack('wide', ['2x1', '1x1', '1x1'])).map(c => c.col), [0, 2, 3]);
    assert.equal(ctx.pack('small', ['4x1']), null);
    assert.equal(ctx.pack('small', ['1x1', '1x1', '1x1']), null);
    assert.equal(ctx.pack('tall', ['2x1', '2x1', '1x1']), null);
    assert.equal(ctx.pack('huge', ['1x1']), null);
    assert.deepEqual(j(ctx.pack('small', [])), []);
});

test('a span that no longer fits the row starts the next one', () => {
    assert.deepEqual(j(ctx.pack('tall', ['1x1', '2x1'])).map(c => [c.col, c.row]), [[0, 0], [0, 1]]);
});

test('boxes follow the page content, not fixed cell sizes', () => {
    // Small page content 316 x 96, Tall 316 x 216, Wide 656 x 96 (cells 170x120 less 12 padding, gap 8)
    assert.deepEqual(j(ctx.boxes('small', 316, 96, 8, ctx.pack('small', ['1x1', '1x1']))), [{ x: 0, y: 0, w: 154, h: 96 }, { x: 162, y: 0, w: 154, h: 96 }]);
    assert.deepEqual(j(ctx.boxes('tall', 316, 216, 8, ctx.pack('tall', ['2x1', '1x1']))), [{ x: 0, y: 0, w: 316, h: 104 }, { x: 0, y: 112, w: 154, h: 104 }]);
    assert.deepEqual(j(ctx.boxes('wide', 656, 96, 8, ctx.pack('wide', ['4x1', ]))), [{ x: 0, y: 0, w: 656, h: 96 }]);
    const w1 = j(ctx.boxes('wide', 656, 96, 8, ctx.pack('wide', ['1x1', '1x1'])));
    assert.equal(w1[0].w, 158);
});

test('a valid blob gives presets with their cells', () => {
    const r = j(ctx.evaluate(blob(p('small', ['1x1', '1x1']), p('tall', ['2x1', '1x1', '1x1'])), registry));
    assert.deepEqual(r.presets.map(x => x.type), ['small', 'tall']);
    assert.equal(r.presets[1].placements[2].row, 1);
    assert.deepEqual(r.hidden, []);
});

test('a placement that does not fit hides the whole preset, others stay, nothing is rewritten', () => {
    const text = blob(p('small', ['4x1'], { id: 'bad' }), p('small', ['1x1'], { id: 'ok' }));
    const r = j(ctx.evaluate(text, registry));
    assert.deepEqual(r.presets.map(x => x.id), ['ok']);
    assert.equal(r.hidden[0].id, 'bad');
    assert.equal(r.log.length, 1);
});

test('a span the widget does not support hides the preset', () => {
    const r = j(ctx.evaluate(blob(p('small', ['2x1'], { placements: [{ widget: 'clock', span: '2x1' }] })), registry));
    assert.equal(r.presets.length, 0);
    assert.match(r.hidden[0].reason, /clock does not support 2x1/);
});

test('a widget that no longer exists keeps its slot', () => {
    const r = j(ctx.evaluate(blob({ id: 'g', name: 'G', page: 'small', placements: [{ widget: 'gone', span: '1x1', settings: { a: 1 }, settingsVersion: 4 }] }), registry));
    assert.equal(r.presets.length, 1);
    assert.deepEqual(r.presets[0].placements[0].settings, { a: 1 });
    assert.equal(r.presets[0].placements[0].settingsVersion, 4);
});

test('at most three presets, duplicate ids and bad pages are hidden', () => {
    const many = [1, 2, 3, 4].map(i => p('small', ['1x1'], { id: 'm' + i }));
    const r = j(ctx.evaluate(blob(...many), registry));
    assert.equal(r.presets.length, 3);
    assert.match(r.hidden[0].reason, /more than 3/);
    const d = j(ctx.evaluate(blob(p('small', ['1x1'], { id: 'a' }), p('small', ['1x1'], { id: 'a' }), p('giant', [], { id: 'b' })), registry));
    assert.equal(d.presets.length, 1);
    assert.equal(d.hidden.length, 2);
});

test('cycle membership defaults to in', () => {
    const r = j(ctx.evaluate(blob(p('small', ['1x1'], { id: 'a' }), p('small', ['1x1'], { id: 'b', inCycle: false })), registry));
    assert.deepEqual(r.presets.map(x => x.inCycle), [true, false]);
});

test('a bad blob gives no presets and a reason', () => {
    assert.deepEqual(j(ctx.evaluate('  ', registry)), { presets: [], hidden: [], log: [] });
    for (const text of ['nope', '[]', '{"format":3,"presets":[]}', '{"format":1}', '{"presets":[]}', '{"format":0,"presets":[]}']) {
        const r = j(ctx.evaluate(text, registry));
        assert.deepEqual(r.presets, [], text);
        assert.equal(r.log.length, 1, text);
    }
});

test('migration: a format with no step is refused, the framework lifts by one step each', () => {
    assert.equal(ctx.migrate({ format: 1, presets: [] }).ok, true);
    assert.equal(ctx.migrate({ format: 99 }).ok, false);
});

test('the deck\'s own page ids are reserved', () => {
    const r = j(ctx.evaluate(blob(p('small', ['1x1'], { id: 'live' }), p('small', ['1x1'], { id: 'control' })), registry));
    assert.equal(r.presets.length, 0);
    assert.equal(r.hidden.length, 2);
});

test('format 1 migrates to 2: every placement gets a unique pid, in order, and the rest is kept', () => {
    const r = j(ctx.migrate({ format: 1, presets: [{ id: 'a', placements: [{ widget: 'clock' }, { widget: 'clock' }] }, { id: 'b', placements: [{ widget: 'weather' }] }] }));
    assert.equal(r.ok, true);
    assert.equal(r.blob.format, 2);
    assert.deepEqual(r.blob.presets.map(x => x.placements.map(q => q.pid)), [['p1', 'p2'], ['p3']]);
    assert.equal(r.blob.presets[0].placements[0].widget, 'clock');
});

test('evaluate passes a pid through and replaces a missing or repeated one', () => {
    const text = JSON.stringify({ format: 2, presets: [
        { id: 'a', page: 'small', placements: [{ pid: 'x', widget: 'clock', span: '1x1' }, { pid: 'x', widget: 'clock', span: '1x1' }] },
        { id: 'b', page: 'small', placements: [{ widget: 'clock', span: '1x1' }] }] });
    const pids = j(ctx.evaluate(text, registry)).presets.map(x => x.placements.map(q => q.pid));
    assert.equal(pids[0][0], 'x');
    assert.equal(new Set(pids.flat()).size, 3);
});

test('keepPids: an unreadable blob keeps the previous pids, a readable one (even with no presets) replaces them', () => {
    const readable = { presets: [{ placements: [{ pid: 'p1' }, { pid: 'p2' }] }] };
    const ok = '{"format":2,"presets":[]}';
    assert.deepEqual(j(ctx.keepPids(ok, readable, [])), ['p1', 'p2']);
    assert.deepEqual(j(ctx.keepPids('not json', { presets: [] }, ['p1'])), ['p1']);
    assert.deepEqual(j(ctx.keepPids('{"format":9,"presets":[]}', { presets: [] }, ['p1'])), ['p1']);
    assert.deepEqual(j(ctx.keepPids('{"presets":[]}', { presets: [] }, ['p1'])), ['p1']);
    assert.deepEqual(j(ctx.keepPids('   ', { presets: [] }, ['p1'])), []);
    assert.deepEqual(j(ctx.keepPids(ok, { presets: [] }, ['p1'])), []);
});

test('ids that name Object members are rejected cleanly, never thrown on', () => {
    const one = (page, widget, span) => blob({ id: 'a', name: 'N', page, placements: [{ widget, span }] });
    for (const widget of ['__proto__', 'constructor', 'toString', 'hasOwnProperty']) {
        const r = j(ctx.evaluate(one('small', widget, '1x1'), registry));
        assert.equal(r.presets.length, 1, widget); // an unknown widget is shown as unavailable, as before
    }
    for (const page of ['constructor', '__proto__', 'toString']) {
        const r = j(ctx.evaluate(one(page, 'clock', '1x1'), registry));
        assert.deepEqual([r.presets.length, r.hidden.length], [0, 1], page);
    }
    for (const span of ['constructor', '__proto__']) {
        const r = j(ctx.evaluate(one('small', 'clock', span), registry));
        assert.deepEqual([r.presets.length, r.hidden.length], [0, 1], span);
    }
    assert.equal(ctx.pack('constructor', []), null);
    assert.equal(ctx.pack('small', ['toString']), null);
});
