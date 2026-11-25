const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const F = load('FormModel.js');
const R = load('WidgetRegistry.js');
const reg = R.build(require('./manifests-source.cjs'));

const field = (type, extra) => Object.assign({ key: 'k', type, label: { en: 'K' }, default: type === 'bool' ? false : type === 'number' ? 1 : 'a' }, extra);
const manifest = (...settings) => ({ id: 'x', version: 1, name: { en: 'X', de: 'Ix' }, spans: ['1x1', '2x1'], settings });

test('each schema type maps to its control; every enum opens the picker page', () => {
    assert.equal(F.controlFor(field('bool')), 'switch');
    assert.equal(F.controlFor(field('enum', { options: ['a', 'b', 'c', 'd'] })), 'picker');
    assert.equal(F.controlFor(field('enum', { options: ['a', 'b'] })), 'picker');
    assert.equal(F.controlFor(field('enum', { options: ['a', 'b', 'c', 'd', 'e'] })), 'picker');
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
    assert.deepEqual(detail.options, [{ value: 'highlow', label: 'High / low', enabled: true }, { value: 'sun', label: 'Sun', enabled: true }]);
    const m = manifest(field('enum', { options: ['a', 'b'] }));
    assert.deepEqual(j(F.build(m, { span: '1x1' }, () => true, 'en').fields[0].options), [{ value: 'a', label: 'a', enabled: true }, { value: 'b', label: 'b', enabled: true }]);
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
        assert.equal(f.fields.length, F.visibleFields(reg.byId[id], reg.byId[id].defaultSpan).length);
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

test('a field with spans shows only for those spans; its stored value is kept when hidden', () => {
    const m = manifest(field('number', { key: 'a', min: 0, max: 9, step: 1 }), field('number', { key: 'b', min: 0, max: 9, step: 1, spans: ['2x1'] }));
    const keys = span => F.build(m, { span, settings: { b: 7 } }, () => true, 'en').fields.map(x => x.key);
    assert.deepEqual(keys('1x1'), ['a']);
    assert.deepEqual(keys('2x1'), ['a', 'b']);
    assert.equal(F.build(m, { span: '2x1', settings: { b: 7 } }, () => true, 'en').fields[1].value, 7);
    assert.deepEqual(F.visibleFields(m, '1x1').map(x => x.key), ['a']);
});

test('the System Monitor shows slot 2 from 2x1 and slots 3 and 4 on 4x1 only', () => {
    const m = reg.byId['system-monitor'];
    const keys = span => F.build(m, { span, settings: {} }, () => true, 'en').fields.map(x => x.key);
    assert.deepEqual(keys('1x1'), ['slot1', 'alerts']);
    assert.deepEqual(keys('2x1'), ['slot1', 'slot2', 'alerts']);
    assert.deepEqual(keys('4x1'), ['slot1', 'slot2', 'slot3', 'slot4', 'alerts']);
});

test('an option whose sensor is missing is disabled in the picker, not removed or replaced', () => {
    const m = reg.byId['system-monitor'];
    const env = { sensors: { 'cpu/all/usage': true, 'cpu/all/maximumTemperature': true } };
    const opts = j(F.build(m, { span: '1x1', settings: {} }, () => true, 'en', env)).fields[0].options;
    assert.equal(opts.length, 7);
    assert.deepEqual(opts.filter(o => o.enabled).map(o => o.value), ['cpu', 'cpuTemp']);
    assert.ok(F.build(m, { span: '1x1', settings: {} }, () => true, 'en', { sensors: null }).fields[0].options.every(o => o.enabled));
    assert.ok(F.build(m, { span: '1x1', settings: {} }, () => true, 'en').fields[0].options.every(o => o.enabled));
});

test('an enum field carries the label of its current option for the form button, and the picker needs room for the longest enum', () => {
    const f = j(F.build(reg.byId.weather, { span: '1x1', settings: { units: 'celsius' } }, () => true, 'en')).fields.find(x => x.key === 'units');
    assert.equal(f.shown, '°C');
    assert.equal(f.control, 'picker');
    assert.equal(F.pickerCount(reg.byId['system-monitor']), 7);
    assert.equal(F.pickerCount(reg.byId.pomodoro), 0);
});
