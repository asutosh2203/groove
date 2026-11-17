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

test('the meta line: paused beats speed; remaining needs a known total', () => {
    assert.deepEqual(j(J.meta(null, false)), { kind: 'none' });
    assert.deepEqual(j(J.meta(null, true)), { kind: 'paused' });
    assert.deepEqual(j(J.meta({ speed: 100, totalBytes: 10 }, true)), { kind: 'paused' });
    assert.deepEqual(j(J.meta({ speed: 0, totalBytes: 10 }, false)), { kind: 'none' });
    assert.deepEqual(j(J.meta({ speed: 1000 }, false)), { kind: 'speed', speed: 1000, remaining: -1 });
    assert.deepEqual(j(J.meta({ speed: 1000, processedBytes: 2500, totalBytes: 10000 }, false)), { kind: 'speed', speed: 1000, remaining: 8 });
    assert.equal(J.meta({ speed: 1000, processedBytes: 20000, totalBytes: 10000 }, false).remaining, 0);
});

test('file count and destination', () => {
    assert.equal(J.fileCount(null), 0);
    assert.equal(J.fileCount({ totalFiles: 3 }), 3);
    assert.equal(J.destination(null), '');
    assert.equal(J.destination({ destUrl: 'file:///home/a/Documents/Holiday%20Pics' }), 'Documents/Holiday Pics');
    assert.equal(J.destination({ destUrl: 'file:///home' }), 'home');
    assert.equal(J.destination({ destUrl: '/x/y/z/' }), 'y/z');
    assert.equal(J.destination({ destUrl: 'file:///%E0%A4%A' }), '%E0%A4%A');
});

test('the job kind: an operation icon wins, else source and destination decide (D-26)', () => {
    assert.equal(J.kind(null, 'edit-copy'), 'copy');
    assert.equal(J.kind(null, 'user-trash'), 'delete');
    assert.equal(J.kind(null, 'go-move'), 'move');
    assert.equal(J.kind(null, 'org.kde.dolphin'), 'generic');
    assert.equal(J.kind(undefined, undefined), 'generic');
    const d = (o) => ({ descriptionValue1: '', descriptionValue2: '', destUrl: '', ...o });
    assert.equal(J.kind(d({ descriptionValue1: 'file:///a/x', destUrl: 'file:///b' }), 'org.kde.dolphin'), 'copy');
    assert.equal(J.kind(d({ descriptionValue1: 'https://h/x', destUrl: 'file:///b/x' }), 'org.kde.dolphin'), 'download');
    assert.equal(J.kind(d({ descriptionValue1: 'file:///a/x', destUrl: 'sftp://h/b' }), ''), 'upload');
    assert.equal(J.kind(d({ descriptionValue1: 'file:///a/x', destUrl: 'trash:/' }), ''), 'delete');
    assert.equal(J.kind(d({ descriptionValue1: 'file:///a/x', totalItems: 3 }), ''), 'delete');
    assert.equal(J.kind(d({ descriptionValue1: 'file:///a/x', descriptionValue2: 'file:///b' }), ''), 'copy');
    assert.equal(J.kind({}, ''), 'generic');
    // Chrome via Plasma Browser Integration, as recorded: remote source, empty destination, one file.
    assert.equal(J.kind(d({ descriptionValue1: 'https://video-downloads.googleusercontent.com/ADGPM2k', totalFiles: 1, totalBytes: 220947078 }), 'google-chrome'), 'download');
    // A real Dolphin copy, as recorded: plain local paths and a file URL.
    assert.equal(J.kind(d({ descriptionValue1: '/home/a/x.mkv', descriptionValue2: '/tmp/x.mkv', destUrl: 'file:///tmp', totalFiles: 1 }), 'org.kde.dolphin'), 'copy');
});

test('every glyph chain ends on a name that exists everywhere', () => {
    for (const k of [null, { destUrl: 'trash:/' }, { descriptionValue1: 'https://h/x', destUrl: 'file:///b' }, { descriptionValue1: 'file:///a', destUrl: 'sftp://h' }, { descriptionValue1: 'file:///a', destUrl: 'file:///b' }]) {
        const names = J.glyphNames(k, '');
        assert.ok(names.length >= 2);
        assert.equal(names[names.length - 1], 'folder-download-symbolic');
    }
    assert.equal(J.glyphNames(null, 'edit-copy')[0], 'edit-copy-symbolic');
    assert.equal(J.glyphNames({ destUrl: 'trash:/', descriptionValue1: 'file:///a' }, '')[0], 'edit-delete-symbolic');
});

test('bytes: the counts, 0 when absent or invalid', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(ctx.bytes({ processedBytes: 5, totalBytes: 10 }))), { processed: 5, total: 10 });
    assert.deepEqual(JSON.parse(JSON.stringify(ctx.bytes({ processedBytes: -3, totalBytes: 'x' }))), { processed: 0, total: 0 });
    assert.deepEqual(JSON.parse(JSON.stringify(ctx.bytes(null))), { processed: 0, total: 0 });
});
