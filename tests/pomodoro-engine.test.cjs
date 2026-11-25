const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const E = load('PomodoroEngine.js');

const MIN = 60000;
const cfg = (focus = 25, brk = 5, rounds = 4, longBreak = 15) => ({ focus, brk, rounds, longBreak });
const kinds = c => j(E.phases(c)).map(p => p.kind[0] + p.ms / MIN);

test('sequence: focus/break per round, then the long break in place of the last break', () => {
    assert.deepEqual(kinds(cfg()), ['f25', 'b5', 'f25', 'b5', 'f25', 'b5', 'f25', 'l15']);
    assert.deepEqual(kinds(cfg(25, 5, 2, 0)), ['f25', 'b5', 'f25']);
    assert.deepEqual(kinds(cfg(25, 0, 3, 15)), ['f25', 'f25', 'f25', 'l15']);
    assert.deepEqual(kinds(cfg(10, 0, 1, 0)), ['f10']);
    assert.deepEqual(kinds(cfg(10, 5, 1, 0)), ['f10']);
    assert.deepEqual(kinds(cfg(10, 5, 1, 15)), ['f10', 'l15']);
});

test('derived lengths come from the settings; one phase is a plain timer', () => {
    assert.deepEqual(j(E.derived(cfg())), { roundMs: 30 * MIN, cycleMs: 130 * MIN, phases: 8, plain: false });
    assert.equal(E.derived(cfg(50, 0, 1, 0)).plain, true);
    assert.equal(E.isPlain(cfg(25, 5, 1, 0)), true);
    assert.equal(E.isPlain(cfg(25, 5, 1, 10)), false);
    assert.deepEqual(j(E.config({ focus: 1, break: 2, rounds: 3, longBreak: 4, dnd: false })), { focus: 1, brk: 2, rounds: 3, longBreak: 4, dnd: false });
});

test('play, pause and resume use deadlines, not counters', () => {
    const c = cfg();
    let s = E.play(E.initial(), c, 1000);
    assert.equal(s.status, 'running');
    assert.equal(s.endsAt, 1000 + 25 * MIN);
    assert.equal(E.remainingMs(s, c, 1000 + 10 * MIN), 15 * MIN);
    s = E.pause(s, 1000 + 10 * MIN);
    assert.equal(s.status, 'paused');
    assert.equal(E.remainingMs(s, c, 9e12), 15 * MIN);
    s = E.play(s, c, 50 * MIN);
    assert.equal(s.endsAt, 65 * MIN);
    assert.equal(E.toggle(s, c, 51 * MIN).status, 'paused');
    assert.equal(E.pause(E.initial(), 0).status, 'ready');
    assert.equal(E.remainingMs(E.initial(), c, 0), 25 * MIN);
});

test('a phase end waits: ended, counted once, nothing advances until play', () => {
    const c = cfg(25, 5, 2, 0);
    let s = E.play(E.initial(), c, 0);
    assert.equal(E.tick(s, c, 25 * MIN - 1).finished, null);
    let r = E.tick(s, c, 25 * MIN);
    assert.equal(r.finished.kind, 'focus');
    assert.equal(r.state.status, 'ended');
    assert.equal(r.state.done, 1);
    assert.equal(E.tick(r.state, c, 99 * MIN).finished, null);
    assert.equal(E.round(r.state, c), 1);
    s = E.play(r.state, c, 30 * MIN);
    assert.equal(E.current(s, c).kind, 'break');
    r = E.tick(s, c, 35 * MIN);
    assert.equal(r.state.done, 1);
    s = E.play(r.state, c, 40 * MIN);
    assert.equal(E.round(s, c), 2);
    r = E.tick(s, c, 65 * MIN);
    assert.equal(r.state.done, 2);
    assert.equal(E.cycleOver(r.state, c), true);
    assert.equal(E.next(r.state, c), null);
    assert.equal(E.play(r.state, c, 70 * MIN).idx, 0);
});

test('skip ends the phase without counting it; reset returns to ready and keeps the count', () => {
    const c = cfg();
    let s = E.play(E.initial(3), c, 0);
    s = E.skip(s);
    assert.equal(s.status, 'ended');
    assert.equal(s.done, 3);
    assert.equal(E.skip(E.initial()).status, 'ready');
    assert.equal(E.skip(s).status, 'ended');
    assert.deepEqual(j(E.reset(E.play(s, c, 1))), { status: 'ready', idx: 0, endsAt: 0, remaining: 0, done: 3 });
    assert.equal(E.skip(E.pause(E.play(E.initial(), c, 0), 5)).status, 'ended');
});

test('dots and timeline follow the passed phases', () => {
    const c = cfg(25, 5, 3, 0);
    assert.deepEqual(j(E.dots(E.initial(), c)), ['current', 'upcoming', 'upcoming']);
    let s = E.play(E.initial(), c, 0);
    s = E.tick(s, c, 25 * MIN).state;
    assert.deepEqual(j(E.dots(s, c)), ['done', 'current', 'upcoming']);
    s = E.play(s, c, 26 * MIN);
    assert.deepEqual(j(E.dots(s, c)), ['done', 'current', 'upcoming']);
    const t = j(E.timeline(s, c, 26 * MIN + 2.5 * MIN));
    assert.deepEqual(t.map(x => x.state), ['done', 'current', 'future', 'future', 'future']);
    assert.equal(t[1].fill, 0.5);
    assert.equal(E.progress(s, c, 26 * MIN + 2.5 * MIN), 0.5);
    assert.deepEqual(j(E.dots({ status: 'ended', idx: 4, endsAt: 0, remaining: 0, done: 3 }, c)), ['done', 'done', 'done']);
});

test('capsule: focus above media, break and waiting below it, ready and paused absent', () => {
    const c = cfg();
    const run = E.play(E.initial(), c, 0);
    assert.deepEqual(j(E.capsule(run, c, 60000)), { tier: 'focus', dot: false, minutes: 25 - 1 + 0, kind: 'focus' });
    assert.equal(E.capsule(run, c, 25 * MIN - 1).minutes, 1);
    const brk = E.play(E.tick(run, c, 25 * MIN).state, c, 26 * MIN);
    assert.equal(E.capsule(brk, c, 26 * MIN).tier, 'break');
    const ended = E.tick(run, c, 25 * MIN).state;
    assert.deepEqual(j(E.capsule(ended, c, 26 * MIN)), { tier: 'break', dot: true, minutes: 0, kind: 'ended' });
    assert.equal(E.capsule(E.initial(), c, 0), null);
    assert.equal(E.capsule(E.pause(run, 5), c, 5), null);
});

test('several timers: waiting first, then running by soonest end; the lead ignores paused and ready', () => {
    const c = cfg();
    const a = E.play(E.initial(), c, 0);
    const b = E.play(E.initial(), c, -5 * MIN);
    const w = E.skip(E.play(E.initial(), c, 0));
    const p = E.pause(E.play(E.initial(), c, 0), 1);
    const ts = [{ pid: 'a', state: a }, { pid: 'p', state: p }, { pid: 'b', state: b }, { pid: 'w', state: w }, { pid: 'r', state: E.initial() }];
    assert.deepEqual(E.order(ts).map(t => t.pid), ['w', 'b', 'a', 'p', 'r']);
    assert.equal(E.lead(ts).pid, 'w');
    assert.equal(E.lead(ts.filter(t => t.pid !== 'w')).pid, 'b');
    assert.equal(E.lead([{ pid: 'p', state: p }]), null);
});

test('alert descriptions', () => {
    const c = cfg(25, 5, 4, 15);
    const at = (idx) => ({ status: 'ended', idx, endsAt: 0, remaining: 0, done: 1 });
    const ph = E.phases(c);
    assert.deepEqual(j(E.alert(ph[0], at(0), c)), { kind: 'focusDone', nextKind: 'break', nextMinutes: 5, round: 1 });
    assert.deepEqual(j(E.alert(ph[1], at(1), c)), { kind: 'breakOver', nextKind: 'focus', nextMinutes: 25, round: 2 });
    assert.deepEqual(j(E.alert(ph[6], at(6), c)), { kind: 'focusDone', nextKind: 'long', nextMinutes: 15, round: 4 });
    assert.equal(E.alert(ph[7], at(7), c).kind, 'cycleDone');
    const plain = cfg(10, 0, 1, 0);
    assert.equal(E.alert(E.phases(plain)[0], at(0), plain).kind, 'timerDone');
});

test('mmss rounds up and switches to hours from 100 minutes; long break time is estimated', () => {
    assert.equal(E.mmss(25 * MIN), '25:00');
    assert.equal(E.mmss(1), '0:01');
    assert.equal(E.mmss(0), '0:00');
    assert.equal(E.mmss(90 * MIN), '90:00');
    assert.equal(E.mmss(100 * MIN + 5000), '1:40:05');
    const c = cfg(25, 5, 2, 10);
    assert.equal(E.longBreakAt(E.initial(), c, 0), 55 * MIN);
    const run = E.play(E.initial(), c, 0);
    assert.equal(E.longBreakAt(run, c, 10 * MIN), 55 * MIN);
    assert.equal(E.longBreakAt(E.initial(), cfg(25, 5, 2, 0), 0), -1);
});

test('snapshot gathers what the views draw', () => {
    const c = cfg();
    const s = j(E.snapshot(E.play(E.initial(), c, 0), c, 5 * MIN));
    assert.equal(s.kind, 'focus');
    assert.equal(s.remainingMs, 20 * MIN);
    assert.deepEqual(s.next, { kind: 'break', ms: 5 * MIN, round: 1 });
    assert.equal(s.round, 1);
    assert.equal(s.timeline.length, 8);
    assert.equal(j(E.snapshot(E.initial(), c, 0)).kind, 'ready');
    assert.equal(j(E.snapshot(E.skip(E.play(E.initial(), c, 0)), c, 0)).endedKind, 'focus');
});

test('dot fills: light over each round\'s focus phase, breaks change nothing', () => {
    const c = cfg(25, 5, 4, 15);
    const at = (s, min, step = 0) => j(E.dotFills(s, c, min * MIN, step));
    assert.deepEqual(at(E.initial(), 0), [0, 0, 0, 0]);
    // round 2 at 12 of 25 minutes
    let s = E.play(E.initial(), c, 0);
    s = E.tick(s, c, 25 * MIN).state;
    s = E.play(s, c, 25 * MIN);
    s = E.tick(s, c, 30 * MIN).state;
    s = E.play(s, c, 30 * MIN);
    assert.deepEqual(at(s, 42), [1, 0.48, 0, 0]);
    // paused keeps its fraction
    assert.deepEqual(at(E.pause(s, 42 * MIN), 99), [1, 0.48, 0, 0]);
    // 15 s steps: 12 min 20 s reads as 12 min 15 s
    assert.equal(at(s, 42 + 20 / 60, 15000)[1], (12 * 60 + 15) / (25 * 60));
    // during the break after round 2's focus the round stays full
    const brk = E.play(E.tick(s, c, 55 * MIN).state, c, 56 * MIN);
    assert.deepEqual(at(brk, 58), [1, 1, 0, 0]);
    // ended waiting for play: the finished focus is full, nothing else
    assert.deepEqual(at(E.tick(E.play(E.initial(), c, 0), c, 25 * MIN).state, 26), [1, 0, 0, 0]);
    // a skipped focus counts as passed
    assert.deepEqual(at(E.skip(E.play(E.initial(), c, 0)), 1), [1, 0, 0, 0]);
});
