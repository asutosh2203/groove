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

test('the accent colour comes from the urgency kind: Critical red, Normal orange (not red), Low grey', () => {
    assert.equal(N.accent('critical'), '#ff453a');
    assert.equal(N.accent('normal'), '#ff9f0a');
    assert.equal(N.accent('low'), '#8f9099');
    assert.equal(N.accent(undefined), '#ff9f0a'); // an unknown kind reads as Normal, never as Critical
    assert.equal(N.accent(4), '#ff9f0a'); // a raw number is not a kind: only the kinds are mapped
    // every kind the mapping can produce has a distinct colour except that Normal is not the Critical red
    assert.notEqual(N.accent(N.urgencyKind(2, levels)), N.accent(N.urgencyKind(4, levels)));
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

// --- row decisions moved out of NotificationService (characterised against it with a mock model) ---------------------

const NOTICE = 1;
const JOB = 2;

test('the first row of a type, and every row of a type with a limit', () => {
    const types = [JOB, NOTICE, NOTICE, JOB, NOTICE];
    assert.equal(N.firstRowOfType(types, NOTICE), 1);
    assert.equal(N.firstRowOfType(types, JOB), 0);
    assert.equal(N.firstRowOfType(types, 9), -1);
    assert.equal(N.firstRowOfType([], NOTICE), -1);
    assert.deepEqual(Array.from(N.rowsOfType(types, NOTICE, 0)), [1, 2, 4]);
    assert.deepEqual(Array.from(N.rowsOfType(types, NOTICE, 2)), [1, 2]);
    assert.deepEqual(Array.from(N.rowsOfType(types, NOTICE, 'x')), [1, 2, 4]); // junk limit means all
    assert.deepEqual(Array.from(N.rowsOfType(types, NOTICE, -3)), [1, 2, 4]);
});

test('the overflow is what does not fit in the limit', () => {
    assert.equal(N.overflow(5, 3), 2);
    assert.equal(N.overflow(2, 3), 0);
    assert.equal(N.overflow(5, 'x'), 5);
    assert.equal(N.overflow(5, -1), 5);
});

test('a notification is found by id as text, and jobs and nullish ids never match', () => {
    const items = [{ type: JOB, id: 7 }, { type: NOTICE, id: 7 }, { type: NOTICE, id: '9' }];
    assert.equal(N.rowOfId(items, 7, NOTICE), 1); // the job with the same id is skipped
    assert.equal(N.rowOfId(items, 9, NOTICE), 2); // 9 matches '9'
    assert.equal(N.rowOfId(items, 5, NOTICE), -1);
    assert.equal(N.rowOfId(items, null, NOTICE), -1);
    assert.equal(N.rowOfId(items, undefined, NOTICE), -1);
});

test('the latest row is the presented one, else the newest notification', () => {
    assert.equal(N.latestRow(3, [0, 1]), 3);
    assert.equal(N.latestRow(-1, [4, 5]), 4);
    assert.equal(N.latestRow(-1, []), -1);
});

test('Clear All closes the closable notifications, last row first, and never jobs', () => {
    const items = [{ type: NOTICE, closable: true }, { type: JOB, closable: true }, { type: NOTICE, closable: false }, { type: NOTICE, closable: true }];
    assert.deepEqual(Array.from(N.closableRows(items, NOTICE)), [3, 0]);
    assert.deepEqual(Array.from(N.closableRows([], NOTICE)), []);
});

test('the open input marks a desktop entry launchable only when it displays', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(N.openInput('org.app', true, false, ['u'], { display: true }))), { expired: true, hasDefaultAction: false, urls: ['u'], desktopEntry: 'org.app', desktopEntryLaunchable: true });
    assert.equal(N.openInput('org.app', 'yes', 1, [], { display: false }).expired, false); // only a real true counts
    assert.equal(N.openInput('org.app', false, true, [], { display: false }).desktopEntryLaunchable, false);
    assert.equal(N.openInput('org.app', false, true, [], undefined).desktopEntryLaunchable, false); // not looked up yet
});

test('a click opens through the live action, or opens the target and then closes the notification if it can', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(N.openPlan('action', true))), { invokeAction: true, openUrl: false, launchApp: false, close: false });
    assert.deepEqual(JSON.parse(JSON.stringify(N.openPlan('url', true))), { invokeAction: false, openUrl: true, launchApp: false, close: true });
    assert.deepEqual(JSON.parse(JSON.stringify(N.openPlan('app', false))), { invokeAction: false, openUrl: false, launchApp: true, close: false });
    assert.equal(N.openPlan('none', true).close, false);
});

// --- urgency kind (D-38) ----------------------------------------------------------------------------------------------

test('KDE urgency maps explicitly: Low 1, Normal 2, Critical 4, and anything else is Normal', () => {
    assert.equal(N.urgencyKind(1, levels), 'low');
    assert.equal(N.urgencyKind(2, levels), 'normal');
    assert.equal(N.urgencyKind(4, levels), 'critical');
    // No range guessing: a value that is not one of the three is Normal, never Critical or Low by accident.
    for (const odd of [0, 3, 5, 8, -1, 1.5, undefined, null, NaN, '4', '1', 'critical'])
        assert.equal(N.urgencyKind(odd, levels), 'normal', String(odd));
});

test('only Normal and Critical notifications are shown as an activity', () => {
    assert.equal(N.kindShowsActivity('critical'), true);
    assert.equal(N.kindShowsActivity('normal'), true);
    assert.equal(N.kindShowsActivity('low'), false);
    assert.equal(N.kindShowsActivity(undefined), false);
    assert.equal(N.kindShowsActivity('urgent'), false);
});

test('no code compares an urgency number with <, <=, > or >= (D-38): kinds are mapped explicitly', () => {
    const root = path.join(__dirname, '../contents');
    const offenders = [];
    const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).forEach((e) => {
        const f = path.join(dir, e.name);
        if (e.isDirectory()) return walk(f);
        if (!/\.(qml|js)$/.test(e.name)) return;
        fs.readFileSync(f, 'utf8').split('\n').forEach((line, n) => {
            const code = line.replace(/\/\/.*$/, '');
            if (/urgency\w*(\([^)]*\))?\s*(>=|<=|>|<)\s*[\w.(]/i.test(code)) offenders.push(`${path.relative(root, f)}:${n + 1}: ${line.trim()}`);
        });
    });
    walk(root);
    assert.deepEqual(offenders, []);
});
