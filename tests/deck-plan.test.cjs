const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/DeckPlan.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const ids = (c) => j(c.map(p => p.id));
const geom = { cellW: 170, cellH: 120, controlW: 430, controlH: 540, controlEditW: 620, controlEditH: 570, capsuleExtra: 37, capsuleW: 126 };
const dummy = () => j(ctx.dummyPresets());

test('cycle: Control Center is always last, Live only when running', () => {
    assert.deepEqual(ids(ctx.buildCycle(false, [])), ['control']);
    assert.deepEqual(ids(ctx.buildCycle(true, [])), ['live', 'control']);
    assert.deepEqual(ids(ctx.buildCycle(true, dummy())), ['live', 'dummy-small', 'dummy-wide', 'dummy-tall', 'control']);
    assert.deepEqual(ids(ctx.buildCycle(false, dummy())).at(-1), 'control');
});

test('page sizes follow the grid and reserve the inset', () => {
    assert.deepEqual(j(ctx.pageSize('small', geom)), { w: 340, h: 120 });
    assert.deepEqual(j(ctx.pageSize('wide', geom)), { w: 680, h: 120 });
    assert.deepEqual(j(ctx.pageSize('tall', geom)), { w: 340, h: 240 });
    assert.deepEqual(j(ctx.pageSize('control', geom)), { w: 430, h: 540 });
});

test('live type: one activity small, two or more tall', () => {
    assert.equal(ctx.liveType(0), 'small');
    assert.equal(ctx.liveType(1), 'small');
    assert.equal(ctx.liveType(2), 'tall');
    assert.equal(ctx.liveType(5), 'tall');
});

test('window union: Live counts as Tall, Control Center as its edit size, every page keeps room for the capsule', () => {
    // Control Center: max(edit 570, 540 + capsule 37) = 577; width 620
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(true, []), geom)), { w: 620, h: 577 });
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, []), geom)), { w: 620, h: 577 });
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, dummy()), geom)), { w: 680, h: 577 });
});

test('the window is at least as wide as the capsule', () => {
    const tiny = { cellW: 10, cellH: 10, controlW: 10, controlH: 10, controlEditW: 10, controlEditH: 10, capsuleExtra: 5, capsuleW: 126 };
    assert.equal(ctx.windowSize([{ id: 'control', type: 'control' }], tiny).w, 126);
});

test('window union takes width and height from different pages', () => {
    const small = { cellW: 100, cellH: 400, controlW: 10, controlH: 10, controlEditW: 10, controlEditH: 10, capsuleExtra: 0, capsuleW: 0 };
    assert.deepEqual(j(ctx.windowSize([{ id: 'a', type: 'wide' }, { id: 'b', type: 'tall' }], small)), { w: 400, h: 800 });
});

test('cell labels follow the grid', () => {
    assert.deepEqual(['small', 'wide', 'tall'].map(ctx.cellLabel), ['2×1', '4×1', '2×2']);
});

test('at most three presets: the rest are dropped and the worst case is five pages', () => {
    const many = [1, 2, 3, 4, 5].map(i => ({ id: 'p' + i, type: 'small' }));
    assert.deepEqual(ids(ctx.buildCycle(true, many)), ['live', 'p1', 'p2', 'p3', 'control']);
    assert.equal(ctx.buildCycle(true, many).length, 5);
    assert.equal(vm.runInContext('maxPresets', ctx), 3);
});

test('direction: a page further right slides content left (+1), further left slides it right (-1)', () => {
    const cycle = ctx.buildCycle(true, dummy());
    assert.equal(ctx.direction(cycle, 'live', 'dummy-wide'), 1);
    assert.equal(ctx.direction(cycle, 'control', 'live'), -1);
    assert.equal(ctx.direction(cycle, 'live', 'control'), 1);
});

test('entry: click goes to Live, else last used, else first; double-click to Control Center', () => {
    const withLive = ctx.buildCycle(true, dummy());
    const noLive = ctx.buildCycle(false, dummy());
    assert.equal(ctx.entryPage(withLive, 'dummy-wide', 'click'), 'live');
    assert.equal(ctx.entryPage(noLive, 'dummy-wide', 'click'), 'dummy-wide');
    assert.equal(ctx.entryPage(noLive, 'gone', 'click'), 'dummy-small');
    assert.equal(ctx.entryPage(noLive, null, 'click'), 'dummy-small');
    assert.equal(ctx.entryPage(ctx.buildCycle(false, []), null, 'click'), 'control');
    assert.equal(ctx.entryPage(withLive, 'live', 'double'), 'control');
});

test('capsule: hidden for one page; glyphs for Live and Control Center, dots for presets, in deck order', () => {
    assert.equal(ctx.indicator(ctx.buildCycle(false, []), 'control'), null);
    const caps = j(ctx.indicator(ctx.buildCycle(true, dummy()), 'dummy-wide'));
    assert.deepEqual(caps.map(i => i.id), ['live', 'dummy-small', 'dummy-wide', 'dummy-tall', 'control']);
    assert.deepEqual(caps.map(i => i.kind), ['glyph', 'dot', 'dot', 'dot', 'glyph']);
    assert.deepEqual(caps.map(i => i.current), [false, false, true, false, false]);
    assert.equal(caps.at(-1).glyphs[0], 'configure-symbolic');
    for (const entry of caps.filter(i => i.kind === 'glyph')) {
        assert.ok(entry.glyphs.length >= 2);
        assert.ok(entry.glyphs.every(n => n.endsWith('-symbolic')));
    }
});

test('only media and job bumps are suppressed, and only while the deck is open', () => {
    assert.equal(ctx.suppressesBump('media', true), true);
    assert.equal(ctx.suppressesBump('job', true), true);
    assert.equal(ctx.suppressesBump('notice', true), false);
    assert.equal(ctx.suppressesBump('keyboard', true), false);
    assert.equal(ctx.suppressesBump('media', false), false);
});

test('reconcile: a surviving page stays, Live appearing does not jump', () => {
    const before = ctx.buildCycle(false, dummy());
    const after = ctx.buildCycle(true, dummy());
    assert.equal(ctx.reconcile(before, after, 'dummy-wide'), 'dummy-wide');
    assert.equal(ctx.reconcile(ctx.buildCycle(false, []), ctx.buildCycle(true, []), 'control'), 'control');
});

test('reconcile: Live emptied while viewed moves to the next page, else Control Center', () => {
    assert.equal(ctx.reconcile(ctx.buildCycle(true, dummy()), ctx.buildCycle(false, dummy()), 'live'), 'dummy-small');
    assert.equal(ctx.reconcile(ctx.buildCycle(true, []), ctx.buildCycle(false, []), 'live'), 'control');
});

test('insets: equal padding on every side, the Control Center keeps its own', () => {
    assert.deepEqual(j(ctx.insets(false, 12)), { l: 12, r: 12, t: 12, b: 12 });
    assert.deepEqual(j(ctx.insets(true, 12)), { l: 14, r: 14, t: 12, b: 16 });
});
