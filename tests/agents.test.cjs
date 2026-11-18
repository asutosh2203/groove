const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');

const A = load('Agents.js');
const snap = (...sessions) => JSON.stringify({ v: 1, sessions });
const s = (o) => ({ id: 'a', agent: 'claude-code', name: 'Claude Code', project: 'groove', pids: [], scopeApp: '', state: 'working', startedAt: 100, updatedAt: 100, ...o });
const p = (o) => j(A.parse(snap(s(o))))[0];

test('parse keeps a valid session, caps text, and reads times as milliseconds', () => {
    const x = p({ task: 'x'.repeat(500), done: 1, total: 3, action: 'edit', target: 'main.qml' });
    assert.equal(x.task.length, 120);
    assert.deepEqual([x.done, x.total, x.action, x.target, x.startedAt], [1, 3, 'edit', 'main.qml', 100000]);
    assert.equal(x.lastMessage, '');
});

test('parse drops a wrong version, bad JSON, and malformed entries instead of throwing', () => {
    assert.deepEqual(j(A.parse('')), []);
    assert.deepEqual(j(A.parse('{nope')), []);
    assert.deepEqual(j(A.parse(JSON.stringify({ v: 2, sessions: [s({})] }))), []);
    assert.deepEqual(j(A.parse(JSON.stringify({ v: 1, sessions: [null, { id: 'x', state: 'weird' }, { state: 'done' }, s({ id: 'ok' })] }))).map((x) => x.id), ['ok']);
});

test('parse sanitises unknown actions, bad counts and bad pids', () => {
    const x = p({ action: 'rm', done: -2, total: 'many', pids: [5, 'x', 0, 1, 7] });
    assert.deepEqual([x.action, x.done, x.total, x.pids], ['', 0, 0, [5, 7]]);
});

test('order: waiting, then working, then done; newest first within a state', () => {
    const o = (xs) => j(A.order(xs)).map((x) => x.id);
    assert.deepEqual(o([s({ id: 'd', state: 'done' }), s({ id: 'w1', startedAt: 1000 }), s({ id: 'q', state: 'waiting' }), s({ id: 'w2', startedAt: 2000 })].map((x) => ({ ...x, startedAt: x.startedAt * 1000 }))),
        ['q', 'w2', 'w1', 'd']);
});

test('minutes are whole and never below 1, and a finished run stops at its last update', () => {
    const x = p({ startedAt: 0 });
    assert.equal(A.minutes(x, 30 * 1000), 1);
    assert.equal(A.minutes(x, 18.9 * 60000), 18);
    assert.equal(A.minutes(p({ startedAt: 0, updatedAt: 120, state: 'done' }), 99 * 60000), 2);
    assert.ok(Math.abs(A.progress(p({ done: 3, total: 7 })) - 3 / 7) < 1e-9);
    assert.equal(A.progress(x), 0);
});

const T0 = 10000000; // ms
const cd = (total, startedAt = T0) => ({ total, startedAt: startedAt / 1000 });

test('compact: priority waiting > countdown > tasks > subagents > verb, and the target never enters', () => {
    const sub = [{ id: 'x', type: 'Plan' }, { id: 'y', type: 'Explore' }];
    const all = { done: 3, total: 7, action: 'edit', target: 'a.qml', countdown: cd(300), subagents: sub };
    assert.equal(A.compact(p({ ...all, state: 'waiting' }), T0).mode, 'waiting');
    assert.deepEqual(j(A.compact(p(all), T0 + 60000)), { project: 'groove', mode: 'countdown', kind: 'edit', minutesLeft: 4 });
    const ended = j(A.compact(p(all), T0 + 301000));
    assert.deepEqual([ended.mode, ended.done, ended.total], ['tasks', 3, 7]); // the bar hands back
    assert.deepEqual([A.compact(p({ subagents: sub }), T0).mode, A.compact(p({ subagents: sub }), T0).count], ['subagents', 2]);
    assert.equal(A.compact(p({ action: 'run' }), T0).mode, 'verb');
    assert.equal(A.compact(p({}), T0).kind, 'other');
    assert.equal(A.compact(p({ action: 'edit', target: 'a' }), T0).kind, A.compact(p({ action: 'edit', target: 'b' }), T0).kind);
});

test('compact countdown: whole minutes rounded up, never zero while it counts, no seconds anywhere', () => {
    const x = p({ countdown: cd(300) });
    assert.equal(A.compact(x, T0).minutesLeft, 5);
    assert.equal(A.compact(x, T0 + 1000).minutesLeft, 5);
    assert.equal(A.compact(x, T0 + 239000).minutesLeft, 2);
    assert.equal(A.compact(x, T0 + 299500).minutesLeft, 1);
    assert.equal(A.compact(p({ countdown: cd(0.5) }), T0).minutesLeft, 1);
});

test('clock formatting: m:ss, h:mm:ss from an hour, never negative', () => {
    assert.deepEqual([0, 9, 72, 192, 3599, 3600, 3723, -5].map(A.formatClock), ['0:00', '0:09', '1:12', '3:12', '59:59', '1:00:00', '1:02:03', '0:00']);
});

test('one clock: countdown, then command (after 10 s), then session minutes', () => {
    const run = { toolStartedAt: T0 / 1000, startedAt: (T0 - 125 * 60000) / 1000 };
    assert.deepEqual(j(A.clock(p(run), T0 + 9000)), { kind: 'session', minutes: 125 });
    assert.deepEqual(j(A.clock(p(run), T0 + 10000)), { kind: 'command', text: '0:10' });
    assert.deepEqual(j(A.clock(p(run), T0 + 72000)), { kind: 'command', text: '1:12' });
    assert.equal(A.clock(p(run), T0 + 3723000).text, '1:02:03');
    const both = p({ ...run, countdown: cd(300) });
    assert.deepEqual(j(A.clock(both, T0 + 108000)), { kind: 'countdown', text: '3:12' });
    assert.deepEqual(j(A.clock(both, T0 + 400000)), { kind: 'countdown', text: '0:00' }); // holds, never negative
    assert.equal(A.clock(p({ state: 'waiting', ...run }), T0 + 50000).kind, 'none');
    assert.equal(A.clock(p({ state: 'done' }), T0).kind, 'none');
});

test('one bar: countdown while it counts, then tasks, else none; the count stays a count', () => {
    const x = p({ countdown: cd(300), done: 3, total: 7 });
    assert.equal(A.barMode(x, T0 + 100000), 'countdown');
    assert.ok(Math.abs(A.barValue(x, T0 + 75000) - 0.25) < 1e-9);
    assert.equal(A.barMode(x, T0 + 300000), 'tasks');
    assert.ok(Math.abs(A.barValue(x, T0 + 400000) - 3 / 7) < 1e-9);
    assert.equal(A.barMode(p({}), T0), 'none');
    assert.equal(A.barMode(p({ done: 1, total: 2 }), T0), 'tasks');
});

test('seconds timer is needed only for a moving clock', () => {
    assert.equal(A.needsSeconds(p({}), T0), false);
    assert.equal(A.needsSeconds(p({ toolStartedAt: T0 / 1000 }), T0 + 1000), true);
    assert.equal(A.needsSeconds(p({ countdown: cd(300), toolStartedAt: T0 / 1000 }), T0 + 1000), true);
    assert.equal(A.needsSeconds(p({ countdown: cd(300), toolStartedAt: T0 / 1000 }), T0 + 400000), false); // held at 0:00
    assert.equal(A.needsSeconds(p({ state: 'waiting', toolStartedAt: 5 }), T0), false);
});

test('line kind follows waiting > countdown > subagents > action', () => {
    const sub = [{ id: 'x', type: 'Plan' }];
    assert.equal(A.lineKind(p({ state: 'waiting', countdown: cd(5), subagents: sub }), T0), 'waiting');
    assert.equal(A.lineKind(p({ countdown: cd(5), subagents: sub }), T0), 'countdown');
    assert.equal(A.lineKind(p({ subagents: sub }), T0), 'subagents');
    assert.equal(A.lineKind(p({}), T0), 'action');
});

test('subagent types are humanised, distinct, in order; unknown types fall back to a count', () => {
    assert.deepEqual(['general-purpose', 'Explore', 'code_reviewer', '', null, '  plan '].map(A.humanType), ['General purpose', 'Explore', 'Code reviewer', '', '', 'Plan']);
    const sm = j(A.subagentSummary(p({ subagents: [{ id: '1', type: 'Explore' }, { id: '2', type: 'general-purpose' }, { id: '3', type: 'Explore' }, { id: '4', type: '' }] })));
    assert.deepEqual(sm, { count: 4, names: ['Explore', 'General purpose'] });
    assert.deepEqual(j(A.subagentSummary(p({ subagents: [{ id: '1', type: '' }] }))), { count: 1, names: [] });
});

test('parse reads the W2.1 fields, bounds subagents and drops a bad countdown', () => {
    const x = p({ toolStartedAt: 100.5, countdown: cd(300), subagents: Array.from({ length: 40 }, (_, i) => ({ id: 'a' + i, type: 'T'.repeat(99) })) });
    assert.equal(x.toolStartedAt, 100500);
    assert.deepEqual(x.countdown, { total: 300, startedAt: T0 });
    assert.equal(x.subagents.length, 16);
    assert.equal(x.subagents[0].type.length, 40);
    for (const bad of [{ total: 0, startedAt: 5 }, { total: -3, startedAt: 5 }, { total: 'x', startedAt: 5 }, null, { total: 5 }])
        assert.equal(p({ countdown: bad }).countdown, null);
    assert.deepEqual([p({}).toolStartedAt, p({}).countdown, p({}).subagents], [0, null, []]);
});

test('elide cuts at the end with an ellipsis and leaves short text alone', () => {
    assert.equal(A.elide('short', 10), 'short');
    assert.equal(A.elide('npm run build --watch', 10), 'npm run b…');
    assert.equal(A.elide(null, 5), '');
});

test('accent: a table entry, else the neutral fallback; prototype names are not entries', () => {
    const t = { 'claude-code': '#d97757' };
    assert.equal(A.accentFor('claude-code', t, '#amber'), '#d97757');
    assert.equal(A.accentFor('codex', t, '#amber'), '#amber');
    assert.equal(A.accentFor('constructor', t, '#amber'), '#amber');
});

test('title match is by whole segment, case-insensitively', () => {
    assert.ok(A.titleMatches('Kove agent - groove - Visual Studio Code', 'groove'));
    assert.ok(A.titleMatches('Groove — Konsole', 'groove'));
    assert.ok(!A.titleMatches('groovy-thing - Visual Studio Code', 'groove'));
    assert.ok(!A.titleMatches('anything', ''));
});

const win = (o) => ({ pid: 0, appId: '', launcherUrl: '', title: '', isWindow: true, lastActivated: 0, ...o });
const find = (o, tasks) => A.findWindow(p(o), tasks);

test('window: a pid in the chain wins; the right window of several sharing a pid is the one titled with the project', () => {
    const tasks = [win({ pid: 9, appId: 'konsole' }), win({ pid: 3386, appId: 'code', title: 'a - other - VS Code', lastActivated: 9 }),
        win({ pid: 3386, appId: 'code', title: 'main.qml - groove - VS Code', lastActivated: 1 })];
    assert.equal(find({ pids: [502116, 3646, 3386] }, tasks), 2);
});

test('window: with no title match the most recently activated of the pid group; a single match needs no title', () => {
    const tasks = [win({ pid: 5, title: 'x', lastActivated: 1 }), win({ pid: 5, title: 'y', lastActivated: 7 })];
    assert.equal(find({ pids: [5] }, tasks), 1);
    assert.equal(find({ pids: [5, 6] }, [win({ pid: 6 })]), 0);
});

test('window: the scope app id is used when no pid matches (a Flatpak), with the same tie-break', () => {
    const tasks = [win({ pid: 1, appId: 'org.kde.konsole' }), win({ appId: 'com.microsoft.VSCode', title: 'a - groove - Code', lastActivated: 1 }),
        win({ appId: 'com.microsoft.VSCode', title: 'b - other - Code', lastActivated: 9 })];
    assert.equal(find({ pids: [999], scopeApp: 'com.microsoft.VSCode' }, tasks), 1);
    assert.equal(find({ pids: [999], scopeApp: 'com.microsoft.VSCode.desktop' }, tasks), 1);
});

test('window: no match is -1, never a guess (not by name, not by recency of another app)', () => {
    const tasks = [win({ pid: 1, appId: 'org.kde.konsole', title: 'groove', lastActivated: 99 })];
    assert.equal(find({ pids: [999] }, tasks), -1);
    assert.equal(find({ pids: [999], scopeApp: 'code' }, tasks), -1);
    assert.equal(find({ pids: [] }, []), -1);
    assert.equal(find({ pids: [999] }, null), -1);
});

test('window: a non-window task and a pid of 0 or 1 never match', () => {
    assert.equal(find({ pids: [5] }, [win({ pid: 5, isWindow: false })]), -1);
    assert.equal(find({ pids: [0, 1] }, [win({ pid: 0 }), win({ pid: 1 })]), -1);
});

test('subtitle detail: the task with a task list, else the host app; never empty text for the name', () => {
    assert.equal(A.subtitleDetail(p({ done: 1, total: 3, task: 'Merge the CC editor' }), 'Code'), 'Merge the CC editor');
    assert.equal(A.subtitleDetail(p({}), 'Code'), 'Code');
    assert.equal(A.subtitleDetail(p({ done: 1, total: 3, task: '' }), 'Code'), 'Code');
    assert.equal(A.subtitleDetail(p({}), undefined), '');
});
