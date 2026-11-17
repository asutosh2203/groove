const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/LiveLayout.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const job = (id, created, extra = {}) => ({ id, row: Number(id.slice(1)), created, percent: 50, processed: 0, total: 0, remaining: -1, kind: 'copy', ...extra });
const lay = (hasMedia, jobs) => j(ctx.layout({ hasMedia, jobs }));

test('shape: 0 or 1 activity is Small, 2 or more Tall', () => {
    assert.deepEqual([0, 1, 2, 5].map(ctx.shape), ['small', 'small', 'tall', 'tall']);
});

test('media alone: Small page, no tray', () => {
    const l = lay(true, []);
    assert.equal(l.shape, 'small');
    assert.equal(l.mediaSlot, true);
    assert.equal(l.mode, 'none');
});

test('one job alone: Small page, one full tile', () => {
    const l = lay(false, [job('j1', 1)]);
    assert.equal(l.shape, 'small');
    assert.equal(l.mode, 'tiles');
    assert.equal(l.trayArea, 'page');
    assert.equal(l.mediaSlot, false);
});

test('media + 1 job: Tall, media on top, one tile in the bottom slot', () => {
    const l = lay(true, [job('j1', 1)]);
    assert.equal(l.shape, 'tall');
    assert.equal(l.mode, 'tiles');
    assert.equal(l.trayArea, 'bottom');
});

test('2 jobs, no media: Tall, two stacked full tiles', () => {
    const l = lay(false, [job('j1', 1), job('j2', 2)]);
    assert.equal(l.shape, 'tall');
    assert.equal(l.mode, 'tiles');
    assert.equal(l.trayArea, 'page');
});

test('media + 2 or more jobs: list in the bottom slot', () => {
    for (const n of [2, 3, 6]) {
        const l = lay(true, Array.from({ length: n }, (_, i) => job('j' + i, i)));
        assert.equal(l.mode, 'list');
        assert.equal(l.trayArea, 'bottom');
    }
});

test('3 or more jobs, no media: list over the whole page', () => {
    const l = lay(false, [job('j1', 1), job('j2', 2), job('j3', 3)]);
    assert.equal(l.mode, 'list');
    assert.equal(l.trayArea, 'page');
});

test('nothing running: an empty Small layout', () => {
    const l = lay(false, []);
    assert.equal(l.count, 0);
    assert.equal(l.mode, 'none');
});

test('jobs are newest first, the row breaks a tie, and the input is not mutated', () => {
    const input = [job('j3', 5), job('j1', 9), job('j2', 9)];
    assert.deepEqual(j(ctx.order(input).map(x => x.id)), ['j1', 'j2', 'j3']);
    assert.deepEqual(j(input.map(x => x.id)), ['j3', 'j1', 'j2']);
});

test('combined percent is byte-weighted when every job reports its size', () => {
    const jobs = [job('j1', 1, { processed: 90, total: 100, percent: 90 }), job('j2', 2, { processed: 100, total: 900, percent: 11 })];
    assert.equal(ctx.combinedPercent(jobs), 19);
});

test('combined percent falls back to the plain mean of known percentages', () => {
    const jobs = [job('j1', 1, { percent: 20 }), job('j2', 2, { percent: 60, total: 10 }), job('j3', 3, { percent: -1 })];
    assert.equal(ctx.combinedPercent(jobs), 40);
    assert.equal(ctx.combinedPercent([job('j1', 1, { percent: -1 })]), -1);
    assert.equal(ctx.combinedPercent([]), -1);
});

test('longest remaining time, -1 when none knows it', () => {
    assert.equal(ctx.longestRemaining([job('j1', 1, { remaining: 4 }), job('j2', 2, { remaining: 120 }), job('j3', 3)]), 120);
    assert.equal(ctx.longestRemaining([job('j1', 1)]), -1);
});

test('header: all one kind uses its noun and no row glyphs', () => {
    const h = j(ctx.header([job('j1', 1, { remaining: 30 }), job('j2', 2, { remaining: 120 }), job('j3', 3)]));
    assert.equal(h.kind, 'copy');
    assert.equal(h.count, 3);
    assert.equal(h.remaining, 120);
    assert.equal(h.rowGlyphs, false);
});

test('header: mixed kinds are generic and rows carry their glyph', () => {
    const h = j(ctx.header([job('j1', 1), job('j2', 2, { kind: 'download' })]));
    assert.equal(h.kind, 'mixed');
    assert.equal(h.rowGlyphs, true);
});

test('header: a generic kind is not a noun, so it reads as mixed', () => {
    const h = j(ctx.header([job('j1', 1, { kind: 'generic' }), job('j2', 2, { kind: 'generic' })]));
    assert.equal(h.kind, 'mixed');
    assert.equal(h.rowGlyphs, true);
});

test('layout carries the header only in list mode', () => {
    assert.equal(lay(false, [job('j1', 1)]).header, null);
    assert.equal(lay(true, [job('j1', 1), job('j2', 2)]).header.count, 2);
});

const geom = { smallH: 120, tallH: 240, chrome: 30, headerH: 24, rowH: 30, gap: 8, mediaGap: 16 };
const listLayout = (hasMedia, n) => j(ctx.layout({ hasMedia, jobs: Array.from({ length: n }, (_, i) => job('j' + i, i)) }));

test('fit height: not a list, no fit height', () => {
    assert.equal(ctx.fitHeight(listLayout(false, 1), geom), null);
    assert.equal(ctx.fitHeight(listLayout(true, 1), geom), null);
    assert.equal(ctx.fitHeight(listLayout(true, 0), geom), null);
});

test('fit height: 3 rows without media shrinks to fit, 2 rows would be tiles', () => {
    // 30 chrome + 24 header + 8 gap + 3 rows (90) + 2 gaps (16) = 168
    assert.equal(ctx.fitHeight(listLayout(false, 3), geom), 168);
});

test('fit height: never below the Small height', () => {
    assert.equal(ctx.fitHeight(listLayout(false, 3), { ...geom, rowH: 10, headerH: 10 }), 120);
});

test('fit height: overflow is capped at the Tall height', () => {
    assert.equal(ctx.fitHeight(listLayout(false, 6), geom), 240);
    assert.equal(ctx.fitHeight(listLayout(false, 9), geom), 240);
});

test('fit height: media + list adds the media card at its Small-page height', () => {
    // 30 + (90 + 16) media + 24 + 8 + 2 rows (60) + 1 gap (8) = 236
    assert.equal(ctx.fitHeight(listLayout(true, 2), geom), 236);
    assert.equal(ctx.fitHeight(listLayout(true, 3), geom), 240);
});
