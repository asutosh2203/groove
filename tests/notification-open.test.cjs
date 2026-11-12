const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/NotificationOpen.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
// Objects from the vm context have another prototype; compare through JSON.
const resolve = (n) => JSON.parse(JSON.stringify(ctx.resolve(n)));

test('a live default action wins over urls and desktop entry', () => {
    assert.deepEqual(resolve({ hasDefaultAction: true, expired: false, urls: ['https://a.example'], desktopEntry: 'app' }), { kind: 'action', target: '' });
});

test('an expired notification falls back to the first url', () => {
    assert.deepEqual(resolve({ hasDefaultAction: true, expired: true, urls: ['https://a.example', 'https://b.example'], desktopEntry: 'app' }), { kind: 'url', target: 'https://a.example' });
});

test('expired with only a desktop entry opens the app, id kept exactly as given', () => {
    assert.deepEqual(resolve({ expired: true, hasDefaultAction: false, urls: [], desktopEntry: ' org.kde.dolphin ' }), { kind: 'app', target: 'org.kde.dolphin' });
    // An id that really ends in ".desktop" (Telegram) must not be stripped.
    assert.deepEqual(resolve({ expired: true, desktopEntry: 'org.telegram.desktop' }), { kind: 'app', target: 'org.telegram.desktop' });
    assert.deepEqual(resolve({ expired: true, desktopEntry: 'firefox.desktop' }), { kind: 'app', target: 'firefox.desktop' });
});

test('no data means not clickable', () => {
    for (const n of [undefined, null, {}, { urls: [], desktopEntry: '' }])
        assert.deepEqual(resolve(n), { kind: 'none', target: '' });
});

test('empty and whitespace values are ignored', () => {
    assert.deepEqual(resolve({ urls: ['', '   ', null, undefined], desktopEntry: '   ' }), { kind: 'none', target: '' });
    assert.deepEqual(resolve({ urls: ['', '  https://c.example  '], desktopEntry: 'app' }), { kind: 'url', target: 'https://c.example' });
});

test('a default action without the flag, or on an expired item, is not an action', () => {
    assert.deepEqual(resolve({ hasDefaultAction: false, desktopEntry: 'app' }), { kind: 'app', target: 'app' });
    assert.deepEqual(resolve({ hasDefaultAction: true, expired: true }), { kind: 'none', target: '' });
});

test('url lists that are not real arrays (Qt list proxies) still work', () => {
    assert.deepEqual(resolve({ urls: { length: 1, 0: 'https://d.example' } }), { kind: 'url', target: 'https://d.example' });
});

test('a desktop entry that cannot be launched (NoDisplay daemon) is not a target', () => {
    assert.deepEqual(resolve({ expired: true, desktopEntry: 'org.kde.kdeconnect.daemon', desktopEntryLaunchable: false }), { kind: 'none', target: '' });
    assert.deepEqual(resolve({ expired: true, desktopEntry: 'org.kde.kate', desktopEntryLaunchable: true }), { kind: 'app', target: 'org.kde.kate' });
    // The URL still wins when the entry is unusable.
    assert.deepEqual(resolve({ expired: true, urls: ['https://a.example'], desktopEntry: 'x', desktopEntryLaunchable: false }), { kind: 'url', target: 'https://a.example' });
});
