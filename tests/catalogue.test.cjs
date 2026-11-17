const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const C = load('Catalogue.js');
const R = load('WidgetRegistry.js');
const manifests = require('./manifests-source.cjs');

const reg = R.build(manifests);
const byName = (list) => Object.fromEntries(list.map(e => [e.id, e]));

test('a full page greys every widget out instead of hiding it', () => {
    const list = j(C.entries(reg, 'small', ['1x1', '1x1'], null, 'en'));
    assert.equal(list.length, reg.ids.length);
    assert.ok(list.every(e => !e.fits));
});

test('per cell: the world clock (2x1) fits a cell only where two columns are free', () => {
    const small = byName(j(C.entries(reg, 'small', ['1x1'], 1, 'en')));
    assert.equal(small.clock.fits, true);
    assert.equal(small['world-clock'].fits, false);
    const tall = byName(j(C.entries(reg, 'tall', ['1x1'], 1, 'en')));
    assert.equal(tall['world-clock'].fits, true);
});

test('per page, the first free spot is tried: a clicked-nowhere add finds the hole or the end', () => {
    const e = byName(j(C.entries(reg, 'tall', ['1x1', '2x1'], null, 'en')));
    assert.equal(e.clock.fits, true);
    assert.equal(e.clock.span, '1x1');
});

test('the span is the widget default when it fits, else the first that does', () => {
    const w = reg.byId.weather;
    assert.deepEqual(j(C.placeAt('wide', [], 0, w)), { ok: true, index: 0, span: '1x1' });
    const fake = { spans: ['2x1', '4x1'], defaultSpan: '4x1' };
    assert.deepEqual(j(C.placeAt('small', [], 0, fake)), { ok: true, index: 0, span: '2x1' });
    assert.deepEqual(j(C.placeAt('wide', [], 0, fake)), { ok: true, index: 0, span: '4x1' });
    assert.equal(C.placeAt('small', ['2x1'], null, fake).ok, false);
});

test('entries carry the localised name, icon chain and the spans label', () => {
    const e = byName(j(C.entries(reg, 'wide', [], null, 'de_DE')));
    assert.equal(e.weather.name, 'Weather');
    assert.equal(e.weather.spansLabel, '1×1 · 2×1 · 4×1');
    assert.ok(e.weather.icon.length > 0);
});
