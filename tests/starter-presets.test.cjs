const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const S = load('StarterPresets.js');
const P = load('Presets.js');
const R = load('WidgetRegistry.js');
const reg = R.build(require('./manifests-source.cjs'));

const free = { locked: false, draftKept: false };
const stored = (...presets) => JSON.stringify({ format: 2, presets });
const mine = (id, name = '') => ({ id, name, inCycle: true, page: 'small', placements: [{ pid: 'x' + id, widget: 'clock', span: '1x1', settings: {} }] });

test('on a fresh install it adds one Wide page, valid under the real registry', () => {
    const r = S.add('', reg, free);
    assert.equal(r.state, 'added');
    assert.equal(r.id, 'p1');
    const shown = P.evaluate(r.json, reg);
    assert.deepEqual(j(shown.log), []);
    assert.equal(shown.presets.length, 1);
    const page = shown.presets[0];
    assert.equal(page.name, 'Essentials');
    assert.equal(page.type, 'wide');
    assert.deepEqual(j(page.placements.map(p => [p.widget, p.span, p.col, p.row])), [['clock', '1x1', 0, 0], ['weather', '1x1', 1, 0], ['pomodoro', '1x1', 2, 0], ['system-monitor', '1x1', 3, 0]]);
});

test('it never touches an existing preset and takes the next free id', () => {
    const before = stored(mine('p1'), mine('p3'));
    const r = S.add(before, reg, free);
    assert.equal(r.state, 'added');
    assert.equal(r.id, 'p2');
    const after = JSON.parse(r.json).presets;
    assert.deepEqual(j(after.slice(0, 1)), j(JSON.parse(before).presets.slice(0, 1)));
    assert.equal(after.length, 3);
    assert.equal(after[0].id, 'p1');
    assert.equal(after[1].id, 'p3');
    assert.equal(after[2].name, 'Essentials');
});

test('the added page gets unique placement ids across the whole blob', () => {
    const r = S.add(stored(mine('p1')), reg, free);
    const pids = JSON.parse(r.json).presets.flatMap(p => p.placements.map(q => q.pid));
    assert.equal(new Set(pids).size, pids.length);
});

test('it is idempotent: with an Essentials page it only points at it', () => {
    const have = stored(mine('p1'), mine('p2', 'Essentials'));
    assert.deepEqual(j(S.status(have, reg, free)), { state: 'exists', id: 'p2' });
    assert.deepEqual(j(S.add(have, reg, free)), { state: 'exists', id: 'p2', json: '' });
});

test('adding twice in a row stores one page', () => {
    const first = S.add('', reg, free);
    assert.equal(S.add(first.json, reg, free).state, 'exists');
});

test('at the preset cap it refuses and stores nothing', () => {
    const full = stored(mine('p1'), mine('p2'), mine('p3'));
    assert.deepEqual(j(S.add(full, reg, free)), { state: 'cap', id: '', json: '' });
});

test('an Essentials page that already exists wins over the cap', () => {
    assert.equal(S.add(stored(mine('p1'), mine('p2'), mine('p3', 'Essentials')), reg, free).state, 'exists');
});

test('it refuses while devPresets is set, while the editor keeps a draft and when the stored blob is unreadable', () => {
    assert.equal(S.add('', reg, { locked: true, draftKept: false }).state, 'locked');
    assert.equal(S.add('', reg, { locked: false, draftKept: true }).state, 'draft');
    assert.equal(S.add('{nope', reg, free).state, 'unreadable');
    assert.equal(S.add(JSON.stringify({ format: 99, presets: [] }), reg, free).state, 'unreadable');
});

test('a retired widget is skipped; with none left it refuses', () => {
    const noPomodoro = { byId: Object.assign({}, reg.byId), ids: reg.ids };
    delete noPomodoro.byId.pomodoro;
    const r = S.add('', noPomodoro, free);
    assert.equal(r.state, 'added');
    assert.deepEqual(j(JSON.parse(r.json).presets[0].placements.map(p => p.widget)), ['clock', 'weather', 'system-monitor']);
    assert.equal(S.add('', { byId: {}, ids: [] }, free).state, 'unavailable');
});

test('other presets that the deck would hide block the write instead of being rewritten', () => {
    const broken = stored({ id: 'p1', name: '', inCycle: true, page: 'small', placements: [{ pid: 'a', widget: 'clock', span: '2x1', settings: {} }] });
    assert.equal(S.add(broken, reg, free).state, 'problem');
});

test('every widget on the page exists in the shipped registry', () => {
    for (const id of S.widgets())
        assert.ok(reg.byId[id], id);
});
