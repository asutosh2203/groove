const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/controlcenter/KdeConnectState.js'), 'utf8');
const k = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), k);
const lit = (pairs) => `[Argument: a{ss} {${pairs.map(([i, n]) => `"${i}" = "${n}"`).join(', ')}}]`;

test('parses the literal D-Bus map and never exposes ids as names', () => {
    const r = k.parseNames(lit([['c791', 'Galaxy S20 FE 5G']]));
    assert.deepEqual(JSON.parse(JSON.stringify(r)), [{ id: 'c791', name: 'Galaxy S20 FE 5G' }]);
});

test('empty, missing or erroring daemon output yields no devices', () => {
    for (const t of ['', null, undefined, '[Argument: a{ss} {}]', 'Error: org.freedesktop.DBus.Error.ServiceUnknown'])
        assert.equal(k.parseNames(t).length, 0);
    assert.equal(k.summaryKind(k.buildDevices(k.parseNames(''), k.parseNames(''))), 'none');
});

test('names with colons, commas, quotes, equals and spaces survive', () => {
    const r = k.parseNames('{"a1" = "Pixel: 8, \\"Pro\\" = x", "b2" = "My  phone"}');
    assert.equal(r[0].name, 'Pixel: 8, "Pro" = x');
    assert.equal(r[1].name, 'My  phone');
});

test('connected, not-nearby and sorted states', () => {
    const paired = k.parseNames(lit([['b', 'Tablet'], ['a', 'Phone'], ['c', 'Zed']]));
    const connected = k.parseNames(lit([['a', 'Phone']]));
    const d = k.buildDevices(paired, connected);
    assert.deepEqual(JSON.parse(JSON.stringify(d.map(x => [x.name, x.reachable]))), [['Phone', true], ['Tablet', false], ['Zed', false]]);
    assert.equal(k.summaryKind(d), 'connected');
    assert.equal(k.connectedCount(d), 1);
    const away = k.buildDevices(paired, []);
    assert.equal(k.summaryKind(away), 'away');
    assert.equal(k.connectedCount(away), 0);
});

test('blank names fall back and the two commands differ', () => {
    assert.equal(k.buildDevices([{ id: 'x', name: '  ' }], [])[0].name, 'Device');
    // const bindings are not context properties, so read them from inside the context.
    assert.notEqual(vm.runInContext('pairedCommand', k), vm.runInContext('connectedCommand', k));
});
