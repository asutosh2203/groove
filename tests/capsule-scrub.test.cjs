const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/CapsuleScrub.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
// Live glyph 22 wide, three dots, Control Center glyph, as the capsule lays them out (uneven on purpose here).
const rects = [{ x: 8, w: 22 }, { x: 30, w: 14 }, { x: 44, w: 14 }, { x: 58, w: 30 }, { x: 88, w: 22 }];
const cs = j(ctx.centres(rects));

test('boundaries are midpoints between centres, not equal slices (5 items)', () => {
    assert.deepEqual(cs, [19, 37, 51, 73, 99]);
    assert.equal(ctx.pick(cs, 19), 0);
    assert.equal(ctx.pick(cs, 27.9), 0);
    assert.equal(ctx.pick(cs, 28), 1);
    assert.equal(ctx.pick(cs, 43.9), 1);
    assert.equal(ctx.pick(cs, 44), 2);
    assert.equal(ctx.pick(cs, 61.9), 2);
    assert.equal(ctx.pick(cs, 62), 3);
    assert.equal(ctx.pick(cs, 85.9), 3);
    assert.equal(ctx.pick(cs, 86), 4);
});

test('clamps at both ends and with a single item', () => {
    assert.equal(ctx.pick(cs, -500), 0);
    assert.equal(ctx.pick(cs, 9999), 4);
    assert.equal(ctx.pick([30], -5), 0);
    assert.equal(ctx.pick([30], 500), 0);
    assert.equal(ctx.pick([], 5), -1);
});

test('a click only hits inside an item, not on the capsule body', () => {
    assert.equal(ctx.hit(cs, 11, 19), 0);
    assert.equal(ctx.hit(cs, 11, 3), -1);
    assert.equal(ctx.hit(cs, 11, 109), 4);
    assert.equal(ctx.hit(cs, 11, 115), -1);
});

test('dwell 0: every crossing commits at once, in order; the same item does not repeat', () => {
    let s = ctx.idle(0);
    const seen = [];
    for (const i of [0, 1, 1, 2, 3, 3]) {
        const r = j(ctx.move(s, i, 0));
        s = r.state;
        if (r.commit >= 0)
            seen.push(r.commit);
    }
    assert.deepEqual(seen, [1, 2, 3]);
});

test('dwell > 0: crossing arms the timer, staying keeps it, rest commits, release commits', () => {
    let r = j(ctx.move(ctx.idle(0), 1, 120));
    assert.deepEqual([r.commit, r.timer], [-1, 120]);
    r = j(ctx.move(r.state, 1, 120));
    assert.deepEqual([r.commit, r.timer], [-1, -1]);
    r = j(ctx.move(r.state, 2, 120));
    assert.deepEqual([r.commit, r.timer], [-1, 120]);
    const fired = j(ctx.rest(r.state));
    assert.equal(fired.commit, 2);
    assert.equal(fired.state.committed, 2);
    // a fast cross to 3 then release: one commit, on release
    r = j(ctx.move(ctx.idle(0), 1, 120));
    r = j(ctx.move(r.state, 2, 120));
    r = j(ctx.move(r.state, 3, 120));
    const rel = j(ctx.release(r.state));
    assert.equal(rel.commit, 3);
    assert.equal(rel.state.scrubbing, false);
});

test('returning to the committed item stops the timer and commits nothing', () => {
    let r = j(ctx.move(ctx.idle(0), 2, 120));
    r = j(ctx.move(r.state, 0, 120));
    assert.deepEqual([r.commit, r.timer], [-1, 0]);
    assert.equal(j(ctx.release(r.state)).commit, -1);
});

test('release-only (reduced motion): never commits while dragging, commits on release', () => {
    let r = j(ctx.move(ctx.idle(0), 2, Infinity));
    assert.deepEqual([r.commit, r.timer], [-1, 0]);
    r = j(ctx.move(r.state, 4, Infinity));
    assert.equal(r.commit, -1);
    assert.equal(j(ctx.release(r.state)).commit, 4);
});

test('release without a scrub commits nothing (a click is handled apart)', () => {
    assert.equal(j(ctx.release(ctx.idle(1))).commit, -1);
});

test('cancel commits nothing and goes back to the committed page', () => {
    let r = j(ctx.move(ctx.idle(0), 3, 120));
    r = j(ctx.cancel(r.state));
    assert.equal(r.commit, -1);
    assert.deepEqual(r.state, { scrubbing: false, hover: 0, committed: 0 });
});

test('the cycle shrinking mid-scrub clamps the pointer item and follows the deck', () => {
    const s = j(ctx.move(ctx.idle(0), 4, 120).state);
    const r = j(ctx.reconcile(s, 3, 1));
    assert.deepEqual(r, { scrubbing: true, hover: 2, committed: 1 });
    assert.deepEqual(j(ctx.reconcile(s, 1, 0)), { scrubbing: true, hover: 0, committed: 0 });
});
