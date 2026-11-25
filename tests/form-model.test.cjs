const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const F = load('FormModel.js');
const R = load('WidgetRegistry.js');
const reg = R.build(require('./manifests-source.cjs'));

const field = (type, extra) => Object.assign({ key: 'k', type, label: { en: 'K' }, default: type === 'bool' ? false : type === 'number' ? 1 : 'a' }, extra);
const manifest = (...settings) => ({ id: 'x', version: 1, name: { en: 'X', de: 'Ix' }, spans: ['1x1', '2x1'], settings });

test('each schema type maps to its control; enums switch to a dropdown past four options', () => {
    assert.equal(F.controlFor(field('bool')), 'switch');
    assert.equal(F.controlFor(field('enum', { options: ['a', 'b', 'c', 'd'] })), 'segmented');
    assert.equal(F.controlFor(field('enum', { options: ['a', 'b', 'c', 'd', 'e'] })), 'dropdown');
    assert.equal(F.controlFor(field('string')), 'text');
    assert.equal(F.controlFor(field('number', { min: 0, max: 10, step: 1 })), 'stepper');
    assert.equal(F.controlFor(field('number', { min: 0, max: 100, step: 1 })), 'stepper');
    assert.equal(F.controlFor(field('location')), 'location');
    assert.equal(F.controlFor(field('timezone')), 'timezone');
    assert.equal(F.controlFor(field('app')), 'app');
});

test('the form carries resolved values, localised labels and the numeric limits', () => {
    const m = manifest(field('number', { min: 2, max: 8, step: 2, default: 4 }), field('bool', { key: 'b', label: { en: 'B', de: 'Be' } }));
    const f = j(F.build(m, { span: '1x1', settings: { k: 6 } }, () => true, 'de_DE'));
    assert.equal(f.title, 'Ix');
    assert.deepEqual(f.fields.map(x => [x.key, x.value, x.label]), [['k', 6, 'K'], ['b', false, 'Be']]);
    assert.deepEqual([f.fields[0].min, f.fields[0].max, f.fields[0].step], [2, 8, 2]);
});

test('a stored value the field would not accept shows the default (the original is not rewritten)', () => {
    const m = manifest(field('enum', { options: ['a', 'b'], default: 'a' }));
    assert.equal(F.build(m, { span: '1x1', settings: { k: 'zzz' } }, () => true, 'en').fields[0].value, 'a');
});

test('enum options use the manifest labels and fall back to the option id', () => {
    const f = j(F.build(reg.byId.weather, { span: '1x1', settings: {} }, () => true, 'en'));
    const detail = f.fields.find(x => x.key === 'detail');
    assert.deepEqual(detail.options, [{ value: 'highlow', label: 'High / low' }, { value: 'sun', label: 'Sun' }]);
    const m = manifest(field('enum', { options: ['a', 'b'] }));
    assert.deepEqual(j(F.build(m, { span: '1x1' }, () => true, 'en').fields[0].options), [{ value: 'a', label: 'a' }, { value: 'b', label: 'b' }]);
});

test('size options grey out spans that cannot fit; the current one always stays enabled', () => {
    const m = manifest();
    const f = j(F.build(m, { span: '1x1', settings: {} }, span => span === '1x1', 'en'));
    assert.deepEqual(f.size, { current: '1x1', options: [{ value: '1x1', enabled: true }, { value: '2x1', enabled: false }] });
    assert.equal(j(F.build(m, { span: '2x1', settings: {} }, () => false, 'en')).size.options[1].enabled, true);
});

test('every real manifest builds a form without throwing', () => {
    for (const id of reg.ids) {
        const f = F.build(reg.byId[id], { span: reg.byId[id].defaultSpan, settings: {} }, () => true, 'en');
        assert.equal(f.fields.length, reg.byId[id].settings.length);
    }
});

test('a number shows its unit, or its zero label at 0', () => {
    const m = manifest(field('number', { min: 0, max: 60, step: 5, default: 15, unit: { en: 'min' }, zeroLabel: { en: 'None', de: 'Keine' } }));
    const f = j(F.build(m, { span: '1x1', settings: {} }, () => true, 'de_DE')).fields[0];
    assert.equal(F.valueText(f, 15), '15 min');
    assert.equal(F.valueText(f, 0), 'Keine');
    assert.equal(F.valueText({ unit: '', zero: '' }, 0), '0');
    assert.equal(F.valueText({ unit: 'min', zero: '' }, 0), '0 min');
});
