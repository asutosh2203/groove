const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/DeckPlan.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const ids = (c) => j(c.map(p => p.id));
const geom = { cellW: 170, cellH: 120, controlW: 430, controlH: 540, controlEditW: 620, controlEditH: 570, railW: 22, railGap: 8 };
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

test('window union: Live counts as Tall, Control Center as its edit size, the rail adds to every other page', () => {
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(true, []), geom)), { w: 620, h: 570 });
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, []), geom)), { w: 620, h: 570 });
    // Wide 680 + rail 30
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, dummy()), geom)), { w: 710, h: 570 });
});

test('window union takes width and height from different pages', () => {
    const small = { cellW: 100, cellH: 400, controlW: 10, controlH: 10, controlEditW: 10, controlEditH: 10, railW: 0, railGap: 0 };
    assert.deepEqual(j(ctx.windowSize([{ id: 'a', type: 'wide' }, { id: 'b', type: 'tall' }], small)), { w: 400, h: 800 });
});

test('cell labels follow the grid', () => {
    assert.deepEqual(['small', 'wide', 'tall'].map(ctx.cellLabel), ['2×1', '4×1', '2×2']);
});

test('a page grows by the rail width plus its gap', () => {
    assert.equal(ctx.railExtra(geom), 30);
});

test('at most three presets: the rest are dropped and the worst case is five pages', () => {
    const many = [1, 2, 3, 4, 5].map(i => ({ id: 'p' + i, type: 'small' }));
    assert.deepEqual(ids(ctx.buildCycle(true, many)), ['live', 'p1', 'p2', 'p3', 'control']);
    assert.equal(ctx.buildCycle(true, many).length, 5);
    assert.equal(vm.runInContext('maxPresets', ctx), 3);
});

test('direction: a page lower on the rail slides content up (+1), higher slides it down (-1)', () => {
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

test('rail: hidden for one page; top to bottom in deck order with glyph chains and the current page flagged', () => {
    assert.equal(ctx.indicator(ctx.buildCycle(false, []), 'control'), null);
    const rail = j(ctx.indicator(ctx.buildCycle(true, dummy()), 'dummy-wide'));
    assert.deepEqual(rail.map(i => i.id), ['live', 'dummy-small', 'dummy-wide', 'dummy-tall', 'control']);
    assert.deepEqual(rail.map(i => i.current), [false, false, true, false, false]);
    assert.equal(rail[0].glyphs[0], 'waveform-symbolic');
    assert.equal(rail.at(-1).glyphs[0], 'configure-symbolic');
    for (const entry of rail) {
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
