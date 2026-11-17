const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/WidgetRegistry.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const good = () => ({
    contract: 1, id: 'demo', name: { en: 'Demo', de: 'Beispiel' }, description: { en: 'd' }, icon: 'x-symbolic',
    spans: ['1x1', '2x1'], defaultSpan: '1x1', category: 'Info', version: 1, services: ['clock'],
    settings: [
        { key: 'tz', type: 'timezone', label: { en: 'Zone' }, default: 'local' },
        { key: 'on', type: 'bool', label: { en: 'On' }, default: true },
        { key: 'mode', type: 'enum', label: { en: 'Mode' }, default: 'a', options: ['a', 'b'] },
        { key: 'n', type: 'number', label: { en: 'N' }, default: 5, min: 1, max: 10, step: 1 },
        { key: 'name', type: 'string', label: { en: 'Name' }, default: '' },
        { key: 'where', type: 'location', label: { en: 'Where' }, default: 'island' },
        { key: 'app', type: 'app', label: { en: 'App' }, default: '' }
    ]
});
const bad = (mutate) => { const m = good(); mutate(m); return j(ctx.validate(m)); };

test('a good manifest validates and the icon becomes a chain', () => {
    const r = j(ctx.validate(good()));
    assert.equal(r.ok, true);
    assert.deepEqual(r.manifest.icon, ['x-symbolic']);
});

test('each broken field is reported', () => {
    assert.equal(bad(m => { m.contract = 2; }).ok, false);
    assert.equal(bad(m => { m.id = 'Bad Id'; }).ok, false);
    assert.equal(bad(m => { m.name = { de: 'x' }; }).ok, false);
    assert.equal(bad(m => { m.spans = ['3x1']; }).ok, false);
    assert.equal(bad(m => { m.spans = []; }).ok, false);
    assert.equal(bad(m => { m.defaultSpan = '4x1'; }).ok, false);
    assert.equal(bad(m => { m.category = 'Other'; }).ok, false);
    assert.equal(bad(m => { m.version = 0; }).ok, false);
    assert.equal(bad(m => { m.services = ['network']; }).ok, false);
    assert.equal(bad(m => { m.settings[0].type = 'colour'; }).ok, false);
    assert.equal(bad(m => { m.settings[2].default = 'z'; }).ok, false);
    assert.equal(bad(m => { m.settings[3].default = 50; }).ok, false);
    assert.equal(bad(m => { m.settings[3].step = 0; }).ok, false);
    assert.equal(bad(m => { m.settings[5].default = { name: 'x', lat: 99, lon: 0 }; }).ok, false);
    assert.equal(bad(m => { m.settings.push(m.settings[0]); }).ok, false);
    assert.equal(ctx.validate(null).ok, false);
    assert.equal(ctx.validate([]).ok, false);
});

test('an invalid manifest is skipped and the others still load', () => {
    const broken = good(); broken.id = 'broken'; broken.spans = [];
    const other = good(); other.id = 'other';
    const r = j(ctx.build([{ id: 'broken', manifest: broken }, { id: 'demo', manifest: good() }, { id: 'other', manifest: other }, { id: 'demo', manifest: good() }, { id: 'x', manifest: null }]));
    assert.deepEqual(r.ids, ['demo', 'other']);
    assert.deepEqual(r.skipped.map(s => s.id), ['broken', 'demo', 'x']);
});

test('a manifest whose id differs from its folder is skipped', () => {
    const r = j(ctx.build([{ id: 'folder', manifest: good() }]));
    assert.deepEqual(r.ids, []);
    assert.equal(r.skipped.length, 1);
});

test('text falls back from locale to language to English', () => {
    const n = { en: 'Demo', de: 'Beispiel', 'pt_BR': 'Exemplo' };
    assert.equal(ctx.text(n, 'de_DE'), 'Beispiel');
    assert.equal(ctx.text(n, 'pt_BR'), 'Exemplo');
    assert.equal(ctx.text(n, 'fr_FR'), 'Demo');
    assert.equal(ctx.text(null, 'en'), '');
});

test('settings resolve to defaults, valid values pass and bad ones fall back', () => {
    const m = good();
    assert.deepEqual(j(ctx.defaults(m)), { tz: 'local', on: true, mode: 'a', n: 5, name: '', where: 'island', app: '' });
    const r = j(ctx.resolveSettings(m, { tz: 'Asia/Tokyo', on: false, mode: 'b', n: 99, name: 'x', where: { name: 'Oslo', lat: 59.9, lon: 10.7 }, junk: 1 }, 1));
    assert.deepEqual(r, { tz: 'Asia/Tokyo', on: false, mode: 'b', n: 10, name: 'x', where: { name: 'Oslo', lat: 59.9, lon: 10.7 }, app: '' });
    const bad2 = j(ctx.resolveSettings(m, { tz: '../etc', on: 'yes', mode: 'zzz', n: 'many', name: 3, where: { name: 'x' } }, 1));
    assert.deepEqual(bad2, { tz: 'local', on: true, mode: 'a', n: 5, name: '', where: 'island', app: '' });
    assert.deepEqual(j(ctx.resolveSettings(m, null, undefined)), j(ctx.defaults(m)));
});

test('a settings version newer than the widget knows is not rewritten', () => {
    const m = good();
    assert.equal(j(ctx.resolveSettings(m, { mode: 'b' }, 7)).mode, 'b');
});
