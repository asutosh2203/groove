const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const logic = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const utils = vm.createContext({});
vm.runInContext(logic('Utils.js'), utils);
const k = vm.createContext({ Utils: { shellQuote: utils.shellQuote } });
vm.runInContext(logic('KdeConnectState.js'), k);
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

// --- device commands: the id is quoted, proven by running the real command through a shell ---------------------------

const { execFileSync } = require('node:child_process');
const os = require('node:os');

// Runs `command` in sh with fake kdeconnect-cli / qdbus6 on PATH that record their arguments, and returns the recorded argv
// plus whether anything other than the fake program ran (a file the hostile id tries to create).
function runForReal(command, canary) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kdeconnect-'));
    const log = path.join(dir, 'argv.json');
    for (const prog of ['kdeconnect-cli', 'qdbus6']) {
        fs.writeFileSync(path.join(dir, prog), `#!/usr/bin/env node\nrequire('fs').writeFileSync(${JSON.stringify(log)}, JSON.stringify(process.argv.slice(2)));\n`, { mode: 0o755 });
    }
    const env = { ...process.env, PATH: dir + ':' + process.env.PATH };
    execFileSync('sh', ['-c', command], { env, cwd: dir });
    const argv = fs.existsSync(log) ? JSON.parse(fs.readFileSync(log, 'utf8')) : null;
    const pwned = fs.existsSync(path.join(dir, canary));
    fs.rmSync(dir, { recursive: true, force: true });
    return { argv, pwned };
}

const hostile = ['plain-id_01', 'has space', "it's", 'say "hi"', 'semi;touch pwned', '$(touch pwned)', '`touch pwned`', 'a&&touch pwned', 'a|touch pwned', '$HOME', 'back\\slash', '*', '-flag', 'new\nline'];

test('the ring command passes any device id as exactly one argument', () => {
    for (const id of hostile) {
        const r = runForReal(k.deviceCommand('ring', id), 'pwned');
        assert.deepEqual(r.argv, ['--device', id, '--ring'], id);
        assert.equal(r.pwned, false, 'ran injected code for ' + id);
    }
});

test('the browse command passes the whole object path as exactly one argument', () => {
    for (const id of hostile) {
        const r = runForReal(k.deviceCommand('browse', id), 'pwned');
        assert.deepEqual(r.argv, ['org.kde.kdeconnect', '/modules/kdeconnect/devices/' + id + '/sftp', 'org.kde.kdeconnect.device.sftp.startBrowsing'], id);
        assert.equal(r.pwned, false, 'ran injected code for ' + id);
    }
});

test('the exact commands for a normal id, and nothing for an unknown action', () => {
    assert.equal(k.deviceCommand('ring', 'c791'), "kdeconnect-cli --device 'c791' --ring");
    assert.equal(k.deviceCommand('browse', 'c791'), "qdbus6 org.kde.kdeconnect '/modules/kdeconnect/devices/c791/sftp' org.kde.kdeconnect.device.sftp.startBrowsing");
    assert.equal(k.deviceCommand('format-disk', 'c791'), null);
    assert.equal(k.deviceCommand(undefined, 'c791'), null);
});
