const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/DeckPlan.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const ids = (c) => j(c.map(p => p.id));
const geom = { cellW: 170, cellH: 120, inset: 16, controlW: 430, controlH: 540, controlEditW: 620, controlEditH: 570 };

test('cycle: Control Center is always last, Live only when running', () => {
    assert.deepEqual(ids(ctx.buildCycle(false, false)), ['control']);
    assert.deepEqual(ids(ctx.buildCycle(true, false)), ['live', 'control']);
    assert.deepEqual(ids(ctx.buildCycle(true, true)), ['live', 'dummy-small', 'dummy-wide', 'dummy-tall', 'control']);
    assert.deepEqual(ids(ctx.buildCycle(false, true)).at(-1), 'control');
});

test('page sizes follow the grid and reserve the inset', () => {
    assert.deepEqual(j(ctx.pageSize('small', geom)), { w: 340, h: 136 });
    assert.deepEqual(j(ctx.pageSize('wide', geom)), { w: 680, h: 136 });
    assert.deepEqual(j(ctx.pageSize('tall', geom)), { w: 340, h: 256 });
    assert.deepEqual(j(ctx.pageSize('control', geom)), { w: 430, h: 540 });
});

test('live type: one card small, two or more wide', () => {
    assert.equal(ctx.liveType(1), 'small');
    assert.equal(ctx.liveType(2), 'wide');
    assert.equal(ctx.liveType(5), 'wide');
});

test('window union: Live counts as Wide, Control Center as its edit size', () => {
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(true, false), geom)), { w: 680, h: 570 });
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, false), geom)), { w: 620, h: 570 });
    assert.deepEqual(j(ctx.windowSize(ctx.buildCycle(false, true), geom)), { w: 680, h: 570 });
});

test('window union takes width and height from different pages', () => {
    const small = { cellW: 100, cellH: 400, inset: 0, controlW: 10, controlH: 10, controlEditW: 10, controlEditH: 10 };
    assert.deepEqual(j(ctx.windowSize([{ id: 'a', type: 'wide' }, { id: 'b', type: 'tall' }], small)), { w: 400, h: 800 });
});

test('entry: click goes to Live, else last used, else first; double-click to Control Center', () => {
    const withLive = ctx.buildCycle(true, true);
    const noLive = ctx.buildCycle(false, true);
    assert.equal(ctx.entryPage(withLive, 'dummy-wide', 'click'), 'live');
    assert.equal(ctx.entryPage(noLive, 'dummy-wide', 'click'), 'dummy-wide');
    assert.equal(ctx.entryPage(noLive, 'gone', 'click'), 'dummy-small');
    assert.equal(ctx.entryPage(noLive, null, 'click'), 'dummy-small');
    assert.equal(ctx.entryPage(ctx.buildCycle(false, false), null, 'click'), 'control');
    assert.equal(ctx.entryPage(withLive, 'live', 'double'), 'control');
});

test('indicator: hidden for one page; pill, dots, gear otherwise', () => {
    assert.equal(ctx.indicator(ctx.buildCycle(false, false), 'control'), null);
    const ind = j(ctx.indicator(ctx.buildCycle(true, true), 'dummy-wide'));
    assert.deepEqual(j(ind.map(i => i.kind)), ['pill', 'dot', 'dot', 'dot', 'gear']);
    assert.deepEqual(j(ind.map(i => i.current)), [false, false, true, false, false]);
});

test('reconcile: a surviving page stays, Live appearing does not jump', () => {
    const before = ctx.buildCycle(false, true);
    const after = ctx.buildCycle(true, true);
    assert.equal(ctx.reconcile(before, after, 'dummy-wide'), 'dummy-wide');
    assert.equal(ctx.reconcile(ctx.buildCycle(false, false), ctx.buildCycle(true, false), 'control'), 'control');
});

test('reconcile: Live emptied while viewed moves to the next page, else Control Center', () => {
    assert.equal(ctx.reconcile(ctx.buildCycle(true, true), ctx.buildCycle(false, true), 'live'), 'dummy-small');
    assert.equal(ctx.reconcile(ctx.buildCycle(true, false), ctx.buildCycle(false, false), 'live'), 'control');
});
