const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the bluetoothctl parsing as it was in main.qml before it moved (the parsing is unchanged).
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const base = vm.createContext({ isFinite, Number, Math, String, parseInt, console });
vm.runInContext(read('Utils.js'), base);
vm.runInContext(read('TextUtils.js'), base);
const ctx = vm.createContext({ TextUtils: { cleanText: base.cleanText }, String });
vm.runInContext(read('Bluetooth.js'), ctx);
const B = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));

const show = 'Controller AA:BB:CC:DD:EE:FF (public)\n\tName: laptop\n\tAlias: cursed-cachy\n\tPowered: yes\n\tDiscoverable: no';

test('connected devices become one name per line', () => {
    assert.equal(B.parseDevices('Device AA:BB:CC:DD:EE:FF My Headphones\nDevice 11:22:33:44:55:66 Mouse'), 'My Headphones\nMouse');
    assert.equal(B.parseDevices('Device AA:BB Single'), 'Single');
    assert.equal(B.parseDevices('  junk  \n\n'), 'junk');
    assert.equal(B.parseDevices(undefined), '');
});

test('the controller output tells availability, power and the adapter name', () => {
    assert.equal(B.parseAvailable(show), true);
    assert.equal(B.parseAvailable('No default controller available'), false);
    assert.equal(B.parsePowered(show), true);
    assert.equal(B.parsePowered(show.replace('Powered: yes', 'Powered: no')), false);
    assert.equal(B.parseAdapterName(show), 'laptop'); // the first of Name: / Alias: in the output wins, and bluetoothctl prints Name: first
    assert.equal(B.parseAdapterName('\tName: onlyname'), 'onlyname');
    assert.equal(B.parseAdapterName(''), '');
});

test('the device count ignores blank lines', () => {
    assert.equal(B.deviceCount(''), 0);
    assert.equal(B.deviceCount('One'), 1);
    assert.equal(B.deviceCount('One\n\nTwo\n'), 2);
});

test('the summary says which line applies', () => {
    assert.deepEqual(j(B.summary(false, true, 'x')), { kind: 'noAdapter' });
    assert.deepEqual(j(B.summary(true, false, 'x')), { kind: 'off' });
    assert.deepEqual(j(B.summary(true, true, '')), { kind: 'on' });
    assert.deepEqual(j(B.summary(true, true, 'Buds')), { kind: 'device', text: 'Buds' });
    assert.deepEqual(j(B.summary(true, true, 'Buds\nMouse')), { kind: 'devices', count: 2 });
});

test('the detail says which line applies', () => {
    assert.deepEqual(j(B.detail(false, true, '', '')), { kind: 'unavailable' });
    assert.deepEqual(j(B.detail(true, false, '', '')), { kind: 'radioOff' });
    assert.deepEqual(j(B.detail(true, true, 'Buds', 'adapter')), { kind: 'devices', text: 'Buds' });
    assert.deepEqual(j(B.detail(true, true, '', 'adapter')), { kind: 'adapter', text: 'adapter' });
    assert.deepEqual(j(B.detail(true, true, '', '')), { kind: 'none' });
});
