const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const E = load('PresetEdit.js');
const P = load('Presets.js');
const R = load('WidgetRegistry.js');
const reg = R.build(require('./manifests-source.cjs'));

const stored = (...presets) => JSON.stringify({ format: 1, presets });
const preset = (id, page, ...widgets) => ({ id, name: '', page, placements: widgets.map(([widget, span]) => ({ widget, span, settings: {} })) });
const draftOf = (...presets) => j(E.load(stored(...presets)).draft);

test('load: an empty value is an empty draft; unreadable data is flagged so it is never saved over', () => {
    assert.deepEqual(j(E.load('')), { readable: true, draft: { presets: [] }, error: '' });
    assert.equal(E.load('{nope').readable, false);
    assert.equal(E.load(JSON.stringify({ format: 99, presets: [] })).readable, false);
    assert.equal(E.load(JSON.stringify({ format: 1 })).readable, false);
});

test('load keeps presets that do not fit, and unknown widgets, so they can be fixed', () => {
    const d = draftOf(preset('a', 'small', ['clock', '1x1'], ['clock', '1x1'], ['clock', '1x1']), preset('b', 'tall', ['gone', '2x1']));
    assert.equal(d.presets.length, 2);
    assert.equal(d.presets[0].placements.length, 3);
    assert.equal(d.presets[1].placements[0].widget, 'gone');
});

test('dirty compares the draft with what was loaded', () => {
    const d = draftOf(preset('a', 'small', ['clock', '1x1']));
    assert.equal(E.dirty(d, d), false);
    assert.equal(E.dirty(d, E.toggleCycle(d, 'a').draft), true);
    assert.equal(E.dirty(d, E.toggleCycle(E.toggleCycle(d, 'a').draft, 'a').draft), false);
});

test('changes never touch their input', () => {
    const d = draftOf(preset('a', 'small', ['clock', '1x1']));
    const before = JSON.stringify(d);
    E.removePlacement(d, 'a', 0);
    E.setPage(d, 'a', 'wide');
    E.addPlacement(d, 'a', 'clock', null, reg);
    assert.equal(JSON.stringify(d), before);
});

test('presets: at most three, new ones are blank Small with the lowest free id', () => {
    let d = { presets: [] };
    for (let i = 0; i < 3; ++i) d = j(E.addPreset(d).draft);
    assert.deepEqual(d.presets.map(p => p.id), ['p1', 'p2', 'p3']);
    assert.deepEqual(j(d.presets[0]), { id: 'p1', name: '', inCycle: true, page: 'small', placements: [] });
    const cap = E.addPreset(d);
    assert.equal(cap.ok, false);
    assert.equal(cap.reason, 'cap');
    d = j(E.removePreset(d, 'p2').draft);
    assert.equal(E.addPreset(d).id, 'p2');
});

test('presets reorder and drop out of the cycle without being removed', () => {
    const d = draftOf(preset('a', 'small'), preset('b', 'small'), preset('c', 'small'));
    assert.deepEqual(j(E.movePreset(d, 0, 2).draft).presets.map(p => p.id), ['b', 'c', 'a']);
    assert.equal(E.movePreset(d, 0, 9).ok, false);
    assert.equal(E.toggleCycle(d, 'b').draft.presets[1].inCycle, false);
    assert.equal(E.removePreset(d, 'zzz').reason, 'missing');
});

test('switching the page type is blocked with the placements that would not fit', () => {
    const d = draftOf(preset('a', 'wide', ['weather', '4x1']));
    const r = E.setPage(d, 'a', 'small');
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'nofit');
    assert.deepEqual(j(r.blocked), [0]);
    assert.equal(r.draft.presets[0].page, 'wide');
    assert.equal(E.setPage(d, 'a', 'wide').ok, true);
});

test('adding a widget: at a cell, at the first free spot, refused when nothing fits', () => {
    let d = draftOf(preset('a', 'small', ['clock', '1x1']));
    const r = E.addPlacement(d, 'a', 'clock', 1, reg);
    assert.equal(r.ok, true);
    assert.deepEqual(j(r.draft.presets[0].placements[1]), { pid: 'p2', widget: 'clock', span: '1x1', settings: {}, settingsVersion: 1 });
    assert.equal(E.addPlacement(r.draft, 'a', 'clock', null, reg).reason, 'nofit');
    assert.equal(E.addPlacement(d, 'a', 'nope', null, reg).reason, 'unknown');
    d = draftOf(preset('t', 'tall', ['clock', '1x1']));
    const w = E.addPlacement(d, 't', 'world-clock', null, reg);
    assert.equal(w.draft.presets[0].placements[w.index].span, '2x1');
});

test('removing, reordering and resizing keep the page valid', () => {
    const d = draftOf(preset('a', 'wide', ['weather', '2x1'], ['clock', '1x1'], ['clock', '1x1']));
    assert.deepEqual(j(E.movePlacement(d, 'a', 0, 2).draft).presets[0].placements.map(p => p.widget), ['clock', 'clock', 'weather']);
    assert.equal(E.removePlacement(d, 'a', 9).reason, 'missing');
    assert.equal(E.removePlacement(d, 'a', 1).draft.presets[0].placements.length, 2);
    assert.equal(E.setSpan(d, 'a', 0, '4x1', reg).reason, 'nofit');
    assert.equal(E.setSpan(d, 'a', 0, '1x1', reg).draft.presets[0].placements[0].span, '1x1');
    assert.equal(E.setSpan(d, 'a', 1, '4x1', reg).reason, 'invalid');
});

test('a setting is stored only when the field would accept it, and stamps the widget version', () => {
    const d = draftOf(preset('a', 'small', ['weather', '1x1']));
    const ok = E.setSetting(d, 'a', 0, 'detail', 'sun', reg);
    assert.equal(ok.ok, true);
    assert.deepEqual(j(ok.draft.presets[0].placements[0]), { pid: 'p1', widget: 'weather', span: '1x1', settings: { detail: 'sun' }, settingsVersion: 1 });
    assert.equal(E.setSetting(d, 'a', 0, 'detail', 'moon', reg).reason, 'invalid');
    assert.equal(E.setSetting(d, 'a', 0, 'nokey', 1, reg).reason, 'invalid');
    const city = { name: 'Oslo', lat: 59.9, lon: 10.75 };
    assert.deepEqual(j(E.setSetting(d, 'a', 0, 'location', city, reg).draft.presets[0].placements[0].settings.location), city);
    assert.equal(E.setSetting(d, 'a', 0, 'location', { name: 'x', lat: 999, lon: 0 }, reg).reason, 'invalid');
});

test('commit writes only a blob the display would show; the cap and bad pages block it', () => {
    const d = draftOf(preset('a', 'small', ['clock', '1x1']), preset('b', 'wide', ['weather', '4x1']));
    const c = E.commit(d, reg);
    assert.equal(c.ok, true);
    const shown = j(P.evaluate(c.json, reg));
    assert.equal(shown.presets.length, 2);
    assert.deepEqual(shown.hidden, []);
    const bad = draftOf(preset('a', 'small', ['clock', '1x1'], ['clock', '1x1'], ['clock', '1x1']));
    const r = E.commit(bad, reg);
    assert.equal(r.ok, false);
    assert.equal(r.blockers[0].id, 'a');
    const four = draftOf(preset('a', 'small'), preset('b', 'small'), preset('c', 'small'), preset('d', 'small'));
    assert.equal(E.commit(four, reg).blockers[0].reason, 'cap');
    assert.equal(E.commit(draftOf(preset('a', 'small'), preset('a', 'small')), reg).ok, false);
    assert.equal(E.commit(draftOf(preset('live', 'small')), reg).ok, false);
});

test('a placement of a widget that is gone is kept and does not block a save', () => {
    const d = draftOf(preset('a', 'tall', ['gone', '2x1']));
    assert.equal(E.commit(d, reg).ok, true);
});

test('discarding is just the original draft: staged deletes come back', () => {
    const original = draftOf(preset('a', 'small'), preset('b', 'small'));
    const staged = E.removePreset(original, 'a').draft;
    assert.equal(E.dirty(original, staged), true);
    assert.equal(original.presets.length, 2);
});

test('the draft weather locations include a place picked but not yet saved', () => {
    const oslo = { name: 'Oslo', lat: 59.9, lon: 10.75 };
    let d = draftOf(preset('a', 'small', ['weather', '1x1'], ['clock', '1x1']));
    assert.deepEqual(j(E.weatherLocations(d, reg)), []);
    d = E.setSetting(d, 'a', 0, 'location', oslo, reg).draft;
    assert.deepEqual(j(E.weatherLocations(d, reg)), [oslo]);
    assert.deepEqual(j(E.weatherLocations(d, { byId: {} })), []);
});

test('pids: unique on load (a repeat gets a fresh one), kept by reorder and settings, fresh for an added placement', () => {
    const text = JSON.stringify({ format: 2, presets: [{ id: 'a', page: 'small', placements: [
        { pid: 'k', widget: 'clock', span: '1x1', settings: {} }, { pid: 'k', widget: 'clock', span: '1x1', settings: {} }] }] });
    const d = j(E.load(text).draft);
    const [first, second] = d.presets[0].placements.map(p => p.pid);
    assert.equal(first, 'k');
    assert.notEqual(second, 'k');
    const moved = j(E.movePlacement(d, 'a', 0, 1).draft);
    assert.deepEqual(moved.presets[0].placements.map(p => p.pid), [second, 'k']);
    const set = j(E.setSetting(d, 'a', 0, 'label', 'x', reg).draft);
    assert.equal(set.presets[0].placements[0].pid, 'k');
    const small = j(E.removePlacement(d, 'a', 1).draft);
    const added = j(E.addPlacement(small, 'a', 'clock', null, reg).draft);
    assert.equal(new Set(added.presets[0].placements.map(p => p.pid)).size, 2);
});
