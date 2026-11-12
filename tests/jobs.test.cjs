const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the job accessors as they were in main.qml before they moved.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const base = vm.createContext({ isFinite, Number, Math, String, parseInt, console });
vm.runInContext(read('Utils.js'), base);
vm.runInContext(read('TextUtils.js'), base);
const ctx = vm.createContext({ Utils: { finiteNumber: base.finiteNumber, hasVisualValue: base.hasVisualValue }, TextUtils: { cleanText: base.cleanText }, isFinite, Number, Math, String, Boolean });
vm.runInContext(read('Jobs.js'), ctx);
const J = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));

test('the job\'s own summary wins over the role, and an empty one is left to the caller', () => {
    assert.equal(J.titleText({ summary: ' Copying  files ' }, 'role'), 'Copying files');
    assert.equal(J.titleText(null, ' From role '), 'From role');
    assert.equal(J.titleText({}, ''), '');
});

test('the text falls back from the job text to the role to the application name', () => {
    assert.equal(J.text({ text: 'a.iso' }, 'body', 'App'), 'a.iso');
    assert.equal(J.text(undefined, 'body', 'App'), 'body');
    assert.equal(J.text({ applicationName: 'Dolphin' }, '', 'Role app'), 'Dolphin');
    assert.equal(J.text(null, '', 'Role app'), 'Role app');
});

test('the icon falls back to the desktop entry, then to a download glyph', () => {
    assert.equal(J.icon({ applicationIconName: 'dolphin' }, 'role', 'e'), 'dolphin');
    assert.equal(J.icon(null, '', 'org.kde.dolphin'), 'org.kde.dolphin');
    assert.equal(J.icon(null, ' ', ' '), 'folder-download');
});

test('state and percentage prefer the details and clamp', () => {
    assert.equal(J.state({ state: 2 }, 1), 2);
    assert.equal(J.state({}, 1), 1);
    assert.equal(J.percentage({ percentage: 42.6 }, -1), 43);
    assert.equal(J.percentage(null, 150), 100);
    assert.equal(J.percentage(null, -50), -1);
    assert.equal(J.percentage({ percentage: 'x' }, 10), -1);
});

test('suspend and kill flags come from the details, else the role as a boolean', () => {
    assert.equal(J.suspendable({ suspendable: false }, true), false);
    assert.equal(J.suspendable(null, 1), true);
    assert.equal(J.killable({}, undefined), false);
    assert.equal(J.killable({ killable: true }, false), true);
});

test('the detail line: paused beats speed beats progress beats the app name', () => {
    assert.deepEqual(j(J.detailsParts(null, false)), { kind: 'none' });
    assert.deepEqual(j(J.detailsParts(null, true)), { kind: 'paused' });
    assert.deepEqual(j(J.detailsParts({ speed: 100, totalBytes: 10 }, true)), { kind: 'paused' });
    assert.deepEqual(j(J.detailsParts({ speed: 2048, totalBytes: 10 }, false)), { kind: 'speed', speed: 2048 });
    assert.deepEqual(j(J.detailsParts({ speed: 0, processedBytes: 5, totalBytes: 10 }, false)), { kind: 'progress', processed: 5, total: 10 });
    assert.deepEqual(j(J.detailsParts({ applicationName: ' Dolphin ' }, false)), { kind: 'app', text: 'Dolphin' });
    assert.deepEqual(j(J.detailsParts({}, false)), { kind: 'app', text: '' });
});
