const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');

const A = load('Agents.js');
const C = load('ClaudeWidget.js');
const NOW = 1_000_000_000_000;
const MIN = 60000;
const s = (o) => ({ id: 'a', project: 'Kove', state: 'working', startedAt: NOW - 5 * MIN, updatedAt: NOW, pids: [], scopeApp: '', action: 'edit', target: 'x.qml',
    waitingCommand: '', waitingAction: '', lastMessage: '', contextPct: 40, costUsd: 0, linesAdded: 0, linesRemoved: 0, ...o });
const win = (pct, min) => ({ pct, resetsAt: NOW + min * MIN });
const model = (o) => ({ usage: { fiveHour: win(34, 60) }, sawLimits: true, spend: {}, sessions: [], recent: [], ...o });
const face = (o) => j(C.face(model(o), NOW));

test('parse: usage windows in ms, absent or malformed windows are absent', () => {
    const u = (usage) => j(A.parseUsage(JSON.stringify({ v: 1, sessions: [], usage })));
    assert.deepEqual(u({ fiveHour: { pct: 34.4, resetsAt: 100 }, sevenDay: { pct: 'x', resetsAt: 5 } }), { fiveHour: { pct: 34, resetsAt: 100000 } });
    assert.deepEqual(u(undefined), {});
    assert.deepEqual(j(A.parseUsage('{nope')), {});
    assert.deepEqual(j(A.parseUsage(JSON.stringify({ v: 2, usage: { fiveHour: { pct: 1, resetsAt: 9 } } }))), {});
});

test('parse: session numbers are sanitised, a null context stays null', () => {
    const p = (o) => j(A.parse(JSON.stringify({ v: 1, sessions: [{ id: 'a', state: 'working', ...o }] })))[0];
    assert.deepEqual([p({ contextPct: 41.6, costUsd: 1.844, linesAdded: 84, linesRemoved: 12 })].map((x) => [x.contextPct, x.costUsd, x.linesAdded, x.linesRemoved])[0], [42, 1.84, 84, 12]);
    assert.equal(p({ contextPct: null }).contextPct, null);
    assert.equal(p({}).contextPct, null);
    assert.equal(p({ contextPct: 900 }).contextPct, 100);
    assert.equal(p({ costUsd: -3, linesAdded: 'x' }).costUsd, 0);
});

test('a report without a window never clears it; a newer report replaces it; expiry drops it', () => {
    const prev = { fiveHour: win(34, 60), sevenDay: win(12, 9000) };
    assert.deepEqual(j(C.mergeUsage(prev, {})), j(prev));
    assert.deepEqual(j(C.mergeUsage(prev, { fiveHour: win(50, 60) })).sevenDay, j(prev.sevenDay));
    assert.equal(j(C.mergeUsage(prev, { fiveHour: win(50, 60) })).fiveHour.pct, 50);
    assert.deepEqual(Object.keys(C.activeUsage({ fiveHour: win(1, -1), sevenDay: win(2, 5) }, NOW)), ['sevenDay']);
});

test('mode: usage while a window lives; spend only when no limits were ever seen; else neutral', () => {
    const m = (usage, saw, usd) => C.mode(C.activeUsage(usage, NOW), saw, { usd, sessions: 1 });
    assert.equal(m({ fiveHour: win(1, 5) }, true, 3), 'usage');
    assert.equal(m({ sevenDay: win(1, 5) }, true, 0), 'usage');
    assert.equal(m({}, false, 1.84), 'spend');
    assert.equal(m({}, true, 1.84), 'neutral'); // a subscriber never sees dollars, even when the window expired
    assert.equal(m({ fiveHour: win(1, -5) }, true, 9), 'neutral');
    assert.equal(m({}, false, 0), 'neutral');
});

test('spend is the highest cost per session, summed; zero cost never counts', () => {
    let map = {};
    map = C.trackSpend(map, [s({ id: 'a', costUsd: 1 }), s({ id: 'b', costUsd: 0 })]);
    map = C.trackSpend(map, [s({ id: 'a', costUsd: 1.5 }), s({ id: 'c', costUsd: 0.34 })]);
    map = C.trackSpend(map, [s({ id: 'a', costUsd: 0.2 })]); // a reset counter never lowers it
    assert.deepEqual(j(C.spendTotal(map)), { usd: 1.84, sessions: 2 });
    const big = C.trackSpend({}, Array.from({ length: 300 }, (_, i) => s({ id: 'x' + i, costUsd: 1 })));
    assert.equal(Object.keys(big).length, 200);
});

test('1x1 usage, sessions running: ring, limit detail, weekly peek', () => {
    const f = face({ sessions: [s({})], usage: { fiveHour: win(34, 60), sevenDay: win(12, 9000) } });
    assert.deepEqual([f.mode, f.resting, f.moon, f.hero, f.detail.kind, f.detail.window, f.peek.kind, f.peek.pct], ['usage', false, false, { kind: 'ring', pct: 34 }, 'limit', 'fiveHour', 'week', 12]);
    assert.equal(face({ sessions: [s({})] }).peek, null); // no weekly window known
    const wk = face({ sessions: [s({})], usage: { sevenDay: win(12, 9000) } });
    assert.deepEqual([wk.hero.pct, wk.detail.window], [12, 'sevenDay']);
});

test('1x1 attention overrides the detail; the peek is the command, elided', () => {
    const f = face({ sessions: [s({ id: 'w', state: 'waiting', waitingAction: 'run', waitingCommand: 'git push origin ' + 'x'.repeat(100) }), s({ id: 'b' })] });
    assert.deepEqual([f.detail.kind, f.detail.n, f.attention, f.peek.kind, f.peek.action, f.target], ['attention', 1, 1, 'wants', 'run', 'w']);
    assert.ok(f.peek.text.length <= 60 && f.peek.text.endsWith('…'));
    assert.equal(f.hero.kind, 'ring');
});

test('1x1 resting: dimmed ring, moon in the label row, caught up, last-session peek', () => {
    const recent = [{ id: 'r', project: 'Afterplay', endedAt: NOW - 18 * MIN }];
    const f = face({ recent });
    assert.deepEqual([f.resting, f.moon, f.hero.kind, f.detail.kind, f.target], [true, true, 'ring', 'caughtUp', null]);
    assert.deepEqual(f.peek, { kind: 'last', project: 'Afterplay', minutes: 18 });
    assert.equal(face({}).peek, null);
    assert.equal(face({ sessions: [s({ state: 'done' })] }).resting, true); // a lingering done session is not live
});

test('1x1 spend mode', () => {
    const base = { usage: {}, sawLimits: false, spend: { a: 1.2, b: 0.64 } };
    const f = face({ ...base, sessions: [s({})] });
    assert.deepEqual([f.mode, f.hero, f.detail], ['spend', { kind: 'cost', usd: 1.84 }, { kind: 'costSessions', n: 2 }]);
    const r = face(base);
    assert.deepEqual([r.moon, r.detail.kind], [true, 'caughtUp']);
    assert.equal(face({ ...base, sessions: [s({ state: 'waiting' })] }).detail.kind, 'attention');
});

test('1x1 neutral: a count while running, the moon as hero when resting, never zero or idle', () => {
    const base = { usage: {}, sawLimits: false, spend: {} };
    const f = face({ ...base, sessions: [s({ id: 'a' }), s({ id: 'b' })] });
    assert.deepEqual([f.mode, f.hero], ['neutral', { kind: 'count', n: 2 }]);
    const r = face(base);
    assert.deepEqual([r.hero.kind, r.moon, r.detail.kind], ['moon', false, 'caughtUp']);
});

test('1x1 click target: waiting, else the most recent live, else none', () => {
    assert.equal(face({ sessions: [s({ id: 'old', startedAt: 1 }), s({ id: 'new', startedAt: 2 })] }).target, 'new');
    assert.equal(face({ sessions: [s({ id: 'new', startedAt: 2 }), s({ id: 'w', state: 'waiting', startedAt: 1 })] }).target, 'w');
    assert.equal(face({}).target, null);
});

test('an expired window shows no ring even if nothing refreshed it', () => {
    const f = face({ usage: { fiveHour: win(34, -1) }, sessions: [s({})] });
    assert.deepEqual([f.mode, f.hero.kind], ['neutral', 'count']);
});

test('remember: finished sessions, newest first, capped at 5, a new prompt takes one out', () => {
    let r = [];
    for (let i = 0; i < 7; i++)
        r = C.remember(r, [s({ id: 'd' + i, state: 'done', updatedAt: NOW + i, lastMessage: 'm' + i })]);
    assert.deepEqual(j(r).map((x) => x.id), ['d6', 'd5', 'd4', 'd3', 'd2']);
    assert.equal(r[0].lastMessage, 'm6');
    assert.deepEqual(j(C.remember(r, [s({ id: 'd6', state: 'working' })])).map((x) => x.id), ['d5', 'd4', 'd3', 'd2']);
    assert.deepEqual(j(C.remember(r, [])).length, 5); // sessions leaving the snapshot stay remembered
    const again = j(C.remember(C.remember([], [s({ id: 'x', state: 'done', updatedAt: 1 })]), [s({ id: 'x', state: 'done', updatedAt: 9 })]));
    assert.deepEqual([again.length, again[0].endedAt], [1, 9]);
});

test('rows: live first (waiting, working), then recent without duplicates', () => {
    const recent = C.remember([], [s({ id: 'r1', state: 'done', updatedAt: NOW, lastMessage: 'Fixed it', linesAdded: 31, linesRemoved: 5, contextPct: null })]);
    const sessions = [s({ id: 'w1', startedAt: 1 }), s({ id: 'p', state: 'waiting', waitingCommand: 'git push', waitingAction: 'run', startedAt: 0 }), s({ id: 'r1', state: 'done' })];
    const rs = j(C.rows(sessions, recent));
    assert.deepEqual(rs.map((r) => r.id), ['p', 'w1', 'r1']);
    assert.deepEqual([rs[0].wants, rs[0].wantsAction, rs[1].wants, rs[2].message, rs[2].added, rs[2].removed, rs[2].context], ['git push', 'run', '', 'Fixed it', 31, 5, null]);
    assert.deepEqual(j(C.rows([], [])), []);
});


// Sticky slots (D-60). Sessions start 10 min apart: a is the oldest.
const sess = (id, o) => s({ id, project: id, startedAt: NOW - (10 - 'abcdefgh'.indexOf(id)) * MIN, updatedAt: NOW - 3 * MIN, ...o });
const wait = (id, at) => sess(id, { state: 'waiting', updatedAt: at ?? NOW, waitingCommand: 'git push' });
const run = (prev, sessions, recent = []) => j(C.assign(prev, sessions, recent));
const empty = { slots: [null, null], waitSince: {} };

test('assign: the first fill is the two most recent sessions by start time', () => {
    const r = run(empty, ['a', 'b', 'c', 'd', 'e'].map((id) => sess(id)));
    assert.deepEqual(r.slots, ['e', 'd']);
});

test('assign: with five sessions a hidden one starting to wait replaces the quieter row, in place', () => {
    const base = ['a', 'b', 'c', 'd', 'e'].map((id) => sess(id, id === 'd' ? { updatedAt: NOW - MIN } : {}));
    const first = run(empty, base);
    assert.deepEqual(first.slots, ['e', 'd']);
    const next = run(first, base.map((x) => (x.id === 'b' ? wait('b') : x)));
    assert.deepEqual(next.slots, ['b', 'd']); // e was quiet longest: b takes its slot
});

test('assign: one row waiting, a new waiter arrives: the older wait goes on top, the newcomer below', () => {
    const base = [sess('a', { updatedAt: NOW - 9 * MIN }), wait('b', NOW - 5 * MIN), sess('c')];
    const first = { slots: ['a', 'b'], waitSince: { b: NOW - 5 * MIN } };
    const next = run(first, [...base.slice(0, 2), wait('c', NOW)]);
    assert.deepEqual(next.slots, ['b', 'c']); // a (working, top) was replaced; b lifts into its slot
    assert.deepEqual(next.waitSince, { b: NOW - 5 * MIN, c: NOW });
    // the same arrival when the waiting row is already on top: the newcomer takes the bottom, nothing crosses
    const top = run({ slots: ['b', 'a'], waitSince: { b: NOW - 5 * MIN } }, [...base.slice(0, 2), wait('c', NOW)]);
    assert.deepEqual(top.slots, ['b', 'c']);
});

test('assign: both visible, the bottom waits first and then the top: the older wait rises to the top', () => {
    const start = { slots: ['a', 'b'], waitSince: {} };
    const one = run(start, [sess('a'), wait('b', NOW - 4 * MIN)]);
    assert.deepEqual(one.slots, ['a', 'b']); // a lone waiter stays below a working row
    const both = run(one, [wait('a', NOW), wait('b', NOW - 4 * MIN)]);
    assert.deepEqual(both.slots, ['b', 'a']);
    assert.deepEqual(run(both, [wait('a', NOW), wait('b', NOW - 4 * MIN)]).slots, ['b', 'a']); // and it stays
});

test('assign: both visible, the top waits first and then the bottom: no swap', () => {
    const one = run({ slots: ['a', 'b'], waitSince: {} }, [wait('a', NOW - 4 * MIN), sess('b')]);
    assert.deepEqual(one.slots, ['a', 'b']);
    assert.deepEqual(run(one, [wait('a', NOW - 4 * MIN), wait('b', NOW)]).slots, ['a', 'b']);
});

test('assign: one waiting and one working: nothing moves, whichever is on top', () => {
    assert.deepEqual(run({ slots: ['a', 'b'], waitSince: {} }, [sess('a'), wait('b')]).slots, ['a', 'b']);
    assert.deepEqual(run({ slots: ['a', 'b'], waitSince: {} }, [wait('a'), sess('b')]).slots, ['a', 'b']);
});

test('assign: both rows waiting, a third waiter gets no row until a slot stops waiting', () => {
    const two = { slots: ['a', 'b'], waitSince: { a: NOW - 8 * MIN, b: NOW - 4 * MIN } };
    const all = [wait('a', NOW - 8 * MIN), wait('b', NOW - 4 * MIN), wait('c', NOW)];
    const r = run(two, all);
    assert.deepEqual(r.slots, ['a', 'b']);
    assert.equal(Object.keys(r.waitSince).length, 3);
    const approved = run(r, [wait('a', NOW - 8 * MIN), sess('b', { updatedAt: NOW }), wait('c', NOW)]);
    assert.deepEqual(approved.slots, ['a', 'c']); // b stopped waiting: the hidden waiter takes that slot
});

test('assign: approving a waiting row does not move it', () => {
    const prev = { slots: ['a', 'b'], waitSince: { b: NOW - 4 * MIN } };
    const r = run(prev, [sess('a'), sess('b', { updatedAt: NOW }), sess('c')]);
    assert.deepEqual(r.slots, ['a', 'b']);
    assert.deepEqual(r.waitSince, {});
});

test('assign: a session ending hands its slot to the next most recent hidden session', () => {
    const all = ['a', 'b', 'c', 'd'].map((id) => sess(id));
    const first = run(empty, all);
    assert.deepEqual(first.slots, ['d', 'c']);
    const ended = run(first, all.map((x) => (x.id === 'd' ? { ...x, state: 'done' } : x)), [{ id: 'd', project: 'd', state: 'done', endedAt: NOW }]);
    assert.deepEqual(ended.slots, ['b', 'c']);
    // nothing hidden: the finished row stays in its slot as an outcome
    const lone = run({ slots: ['a', 'b'], waitSince: {} }, [sess('a')], [{ id: 'b', project: 'b', state: 'done', endedAt: NOW }]);
    assert.deepEqual(lone.slots, ['a', 'b']);
    // and the next session to start takes that finished slot
    const fresh = run(lone, [sess('a'), sess('c')], [{ id: 'b', project: 'b', state: 'done', endedAt: NOW }]);
    assert.deepEqual(fresh.slots, ['a', 'c']);
});

test('assign: activity alone never re-shuffles, and a busier hidden session is not promoted', () => {
    const all = ['a', 'b', 'c'].map((id) => sess(id));
    const first = run(empty, all);
    const busy = run(first, all.map((x) => (x.id === 'a' ? { ...x, updatedAt: NOW + MIN, action: 'run' } : { ...x, updatedAt: NOW - 20 * MIN })));
    assert.deepEqual(busy.slots, first.slots);
    assert.deepEqual(run(busy, all).slots, first.slots);
});

test('assign: sessions that vanish leave their slot to the recent outcomes', () => {
    const r = run({ slots: ['a', 'x'], waitSince: {} }, [sess('a')], [{ id: 'z', project: 'z', state: 'done', endedAt: NOW }]);
    assert.deepEqual(r.slots, ['a', 'z']);
    assert.deepEqual(run(empty, [], []).slots, [null, null]);
});

test('slotHeights: the slots fill the span, with the same padding above and below every row', () => {
    const plain = 22;
    const asks = 41;
    const gap = 4;
    const check = (contents) => {
        const h = C.slotHeights(100, gap, contents);
        assert.equal(h.reduce((a, x) => a + x, 0) + gap, 100);
        const pads = h.map((x, i) => (x - contents[i]) / 2);
        assert.ok(pads.every((p) => Math.abs(p - pads[0]) < 1e-9));
        return h;
    };
    const neither = check([plain, plain]);
    const both = check([asks, asks]);
    assert.equal(neither[0], neither[1]);
    assert.equal(both[0], both[1]);
    const top = check([asks, plain]);
    const bottom = check([plain, asks]);
    assert.ok(top[0] > top[1] && bottom[1] > bottom[0]);
    assert.deepEqual([top[0], top[1]], [bottom[1], bottom[0]]);
    assert.deepEqual(j(C.slotHeights(100, gap, [plain])), [100]);
    assert.deepEqual(j(C.slotHeights(100, gap, [])), []);
    // no room: no negative padding
    assert.deepEqual(j(C.slotHeights(40, gap, [30, 30])), [30, 30]);
});

test('contentHeight: the name line, plus the hairline when the context is known, plus the accent line when waiting', () => {
    const h = (o) => C.contentHeight(o, 12, 2, 12, 4);
    assert.equal(h({ context: 40, state: 'working' }), 18);
    assert.equal(h({ context: null, state: 'working' }), 12);
    assert.equal(h({ context: 40, state: 'waiting' }), 34);
    assert.equal(h({ context: null, state: 'waiting' }), 28);
});

test('layout: slots inset from the tile and from each other, filling the height', () => {
    const rows = [{ context: 40, state: 'waiting' }, { context: 40, state: 'working' }];
    const l = j(C.layout(rows, 100, 4, 12, 2, 4));
    assert.equal(l.tops[0], 4);
    assert.equal(l.tops[1], 4 + l.heights[0] + 4);
    assert.equal(l.tops[1] + l.heights[1], 100 - 4);
    assert.ok(l.heights[0] > l.heights[1]);
    assert.deepEqual(j(C.layout([], 100, 4, 12, 2, 4)), { tops: [], heights: [] });
});
