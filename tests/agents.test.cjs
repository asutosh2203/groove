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

test('compact parts: a task list gives done/total, else the action kind; the target never enters', () => {
    assert.deepEqual(j(A.compactParts(p({ done: 3, total: 7, action: 'edit', target: 'a.qml' }))), { project: 'groove', waiting: false, progress: { done: 3, total: 7 }, kind: 'edit' });
    const w = j(A.compactParts(p({ action: 'run', target: 'npm test' })));
    assert.deepEqual([w.progress, w.kind, w.waiting], [null, 'run', false]);
    assert.equal(j(A.compactParts(p({}))).kind, 'other');
    assert.equal(j(A.compactParts(p({ action: 'edit', target: 'a.qml' }))).kind, j(A.compactParts(p({ action: 'edit', target: 'b.qml' }))).kind);
});

test('compact parts: waiting wins (the caller shows "Needs your OK")', () => {
    assert.equal(j(A.compactParts(p({ state: 'waiting', done: 1, total: 3 }))).waiting, true);
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
