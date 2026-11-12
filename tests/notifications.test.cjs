const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the notification accessors as they were in main.qml before they moved.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const base = vm.createContext({ isFinite, Number, Math, String, Date, parseInt, console });
vm.runInContext(read('Utils.js'), base);
vm.runInContext(read('TextUtils.js'), base);
const ctx = vm.createContext({ Utils: { finiteNumber: base.finiteNumber, hasVisualValue: base.hasVisualValue }, TextUtils: { cleanText: base.cleanText }, isFinite, Number, Math, String, Date });
vm.runInContext(read('Notifications.js'), ctx);
const N = ctx;
const levels = { low: 1, critical: 4 };

test('the app name falls back to the desktop entry, then to the given default', () => {
    assert.equal(N.appName('  Telegram ', 'org.telegram.desktop', 'Notification'), 'Telegram');
    assert.equal(N.appName('', 'org.telegram.desktop', 'Notification'), 'org.telegram.desktop');
    assert.equal(N.appName(undefined, null, 'Notification'), 'Notification');
});

test('the title falls back to the app name', () => {
    assert.equal(N.title('Hello', 'App'), 'Hello');
    assert.equal(N.title('  ', 'App'), 'App');
});

test('icons fall back from the notification to the app to the generic one', () => {
    assert.equal(N.appIcon('telegram', 'x'), 'telegram');
    assert.equal(N.appIcon('', 'org.kde.dolphin'), 'org.kde.dolphin');
    assert.equal(N.appIcon('', ''), 'notifications');
    assert.equal(N.mainIcon('mail-unread', 'app'), 'mail-unread');
    assert.equal(N.mainIcon(' ', 'app'), 'app');
});

test('the main image is the image, else the first attached image file, else null', () => {
    assert.equal(N.mainImage('image://x', ['a.png']), 'image://x');
    assert.equal(N.mainImage('', ['http://a/readme.txt', 'http://a/pic.WEBP?size=2']), 'http://a/pic.WEBP?size=2');
    assert.equal(N.mainImage(null, ['file:///a.png#frag']), 'file:///a.png#frag');
    assert.equal(N.mainImage(null, ['http://a/b.txt']), null);
    assert.equal(N.mainImage(null, 'not-a-list'), null);
    assert.equal(N.mainImage(null, undefined), null);
});

test('urgency uses KDE\'s enum and unknown values never read as critical', () => {
    assert.equal(N.urgencyColor(1, levels), '#6c6e78'); // low: grey
    assert.equal(N.urgencyColor(2, levels), '#3ac255'); // normal: green
    assert.equal(N.urgencyColor(4, levels), '#E66A65'); // critical: red
    assert.equal(N.urgencyColor(7, levels), '#3ac255');
    assert.equal(N.urgencyColor(undefined, levels), '#3ac255');
});

test('urgency as a number and the accent colour', () => {
    assert.equal(N.urgency(undefined), 1);
    assert.equal(N.urgency('4'), 4);
    assert.equal(N.urgency(NaN), 1);
    assert.equal(N.accent(4), '#ff453a');
    assert.equal(N.accent(2), '#ff453a');
    assert.equal(N.accent(1), '#ff9f0a');
    assert.equal(N.accent(0), '#8f9099');
});

test('created time accepts a Date or a number and returns 0 for anything unusable', () => {
    assert.equal(N.createdMs(new Date(1700000000000)), 1700000000000);
    assert.equal(N.createdMs(1700000000000), 1700000000000);
    assert.equal(N.createdMs(null), 0);
    assert.equal(N.createdMs('x'), 0);
    assert.equal(N.createdMs(-5), 0);
});

test('only recent notifications are arrivals, and none while Clear All runs', () => {
    const now = 1700000000000;
    assert.equal(N.isFresh(new Date(now - 5000), now, false), true);
    assert.equal(N.isFresh(new Date(now - 16000), now, false), false);
    assert.equal(N.isFresh(now - 14000, now, false), true);
    assert.equal(N.isFresh(null, now, false), true); // unknown age counts as fresh
    assert.equal(N.isFresh('x', now, false), true);
    assert.equal(N.isFresh(new Date(now - 5000), now, true), false);
});
