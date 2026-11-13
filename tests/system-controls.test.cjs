const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the system-control functions as they were in main.qml before they moved (mock devices).
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const base = vm.createContext({ isFinite, Number, Math, String, parseInt, console });
vm.runInContext(read('Utils.js'), base);
const Utils = {};
for (const k of ['finiteNumber', 'clampNumber', 'percentFromRatio', 'firstValidNumber']) Utils[k] = base[k];
const ctx = vm.createContext({ Utils, Math, String });
vm.runInContext(read('SystemControls.js'), ctx);
const S = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));

test('screen percent is known once the display reported, otherwise falls back to the raw row', () => {
    assert.equal(S.screenPercent('display0', 2000, 10000), 20);
    assert.equal(S.screenPercent('', 2000, 10000), -1);
    assert.equal(S.screenPercent('display0', 2000, 0), -1);
    assert.equal(S.displayRowPercent([undefined, 30], [undefined, 60]), 50);
    assert.equal(S.displayRowPercent(['x', 'y'], [undefined, undefined]), 0);
});

test('a pinned slider shows the dragged value until the device catches up', () => {
    assert.equal(S.displayedScreenPercent(true, true, 70, 20), 70);
    assert.equal(S.displayedScreenPercent(true, false, 70, 20), 20);
    assert.equal(S.displayedScreenPercent(false, true, 70, 20), 0);
    assert.deepEqual(j(S.syncDisplay('d', 2000, 10000, true, 70)), { displayName: 'd', value: 2000, max: 10000, visualPercent: 70, pinned: true });
    assert.deepEqual(j(S.syncDisplay('d', 7000, 10000, true, 70)), { displayName: 'd', value: 7000, max: 10000, visualPercent: 70, pinned: false }); // within 1 %: released
    assert.deepEqual(j(S.syncDisplay(undefined, 50, 0, false, 0)), { displayName: '', value: 1, max: 1, visualPercent: 100, pinned: false });
});

test('setting the screen brightness gives an absolute value for a known display, else a ratio step', () => {
    assert.deepEqual(j(S.screenTarget(50, 'display0', 10000, 20)), { percent: 50, absolute: 5000, ratio: 0.3 });
    assert.deepEqual(j(S.screenTarget(150, 'display0', 10000, 20)), { percent: 100, absolute: 10000, ratio: 0.8 });
    assert.equal(S.screenTarget(50, '', 0, 20).absolute, null);
});

test('keyboard backlight percent and target need a backlight', () => {
    assert.equal(S.keyboardPercent(true, 3, 1), 33);
    assert.equal(S.keyboardPercent(false, 3, 1), 0);
    assert.equal(S.keyboardPercent(true, 0, 1), 0);
    assert.equal(S.keyboardTarget(true, 3, 100), 3);
    assert.equal(S.keyboardTarget(true, 3, 40), 1);
    assert.equal(S.keyboardTarget(false, 3, 40), null);
});

test('volume reads and sets 0..150 %, so a boosted sink shows above 100', () => {
    assert.equal(S.volumePercent(0, 65536), 0);
    assert.equal(S.volumePercent(49152, 65536), 75);
    assert.equal(S.volumePercent(65536, 65536), 100);
    assert.equal(S.volumePercent(80000, 65536), 122);
    assert.equal(S.volumePercent(98304, 65536), 150);
    assert.equal(S.volumePercent(1e9, 65536), 150); // capped at what the setter accepts
    assert.equal(S.volumePercent(-5, 65536), 0);
    assert.equal(S.volumePercent('junk', 65536), 0);
    assert.equal(S.volumePercent(0, 0), 0); // a bad reference is floored at 1: no division by zero, no NaN
    assert.equal(S.volumePercent(65536, 0), 150);
    assert.equal(S.volumeTarget(100, 65536), 65536);
    assert.equal(S.volumeTarget(122, 65536), 79954);
    assert.equal(S.volumeTarget(500, 65536), 98304);
    assert.equal(S.volumeTarget(-3, 65536), 0);
});

test('every power action maps to its command and nothing else does', () => {
    assert.equal(S.powerCommand('lock'), 'loginctl lock-session');
    assert.equal(S.powerCommand('logout'), 'qdbus6 org.kde.Shutdown /Shutdown logout');
    assert.equal(S.powerCommand('sleep'), 'systemctl suspend');
    assert.equal(S.powerCommand('hibernate'), 'systemctl hibernate');
    assert.equal(S.powerCommand('reboot'), 'systemctl reboot');
    assert.equal(S.powerCommand('shutdown'), 'systemctl poweroff');
    for (const bad of ['', 'poweroff', 'LOCK', undefined, null, 'suspend; rm -rf ~'])
        assert.equal(S.powerCommand(bad), null, String(bad));
});

test('the power profile cycles round and maps to an icon and a name kind', () => {
    const all = ['power-saver', 'balanced', 'performance'];
    assert.equal(S.nextProfile(all, 'power-saver'), 'balanced');
    assert.equal(S.nextProfile(all, 'performance'), 'power-saver');
    assert.equal(S.nextProfile(all, 'unknown'), 'balanced'); // not found counts as the first
    assert.equal(S.nextProfile([], 'x'), null);
    assert.equal(S.nextProfile(undefined, 'x'), null);
    assert.equal(S.profileIcon('performance'), 'battery-profile-performance');
    assert.equal(S.profileIcon('power-saver'), 'battery-profile-powersave');
    assert.equal(S.profileIcon('anything'), 'battery-profile-balanced');
    assert.equal(S.profileKind('power-saver'), 'saver');
    assert.equal(S.profileKind('performance'), 'performance');
    assert.equal(S.profileKind(''), 'balanced');
});

test('the battery shows the charge, or AC / Power on a machine without one', () => {
    assert.equal(S.batteryKind(true, false), 'percent');
    assert.equal(S.batteryKind(true, true), 'percent');
    assert.equal(S.batteryKind(false, true), 'ac');
    assert.equal(S.batteryKind(false, false), 'power');
});

test('the profile face prefers the account icon, then the user\'s AccountsService icon', () => {
    assert.equal(S.accountIconUrl('/home/a/.face'), 'file:///home/a/.face');
    assert.equal(S.accountIconUrl('file:///x.png'), 'file:///x.png');
    assert.equal(S.accountIconUrl(''), '');
    assert.equal(S.faceUrl('file:///a.png', 'u'), 'file:///a.png');
    assert.equal(S.faceUrl('', 'asutosh'), 'file:///var/lib/AccountsService/icons/asutosh');
    assert.equal(S.faceUrl('', undefined), '');
});

test('layout names fall back from long to display to short', () => {
    const list = [{ shortName: 'us', displayName: 'English (US)', longName: 'English (US) layout' }, { shortName: 'de' }];
    assert.deepEqual(j(S.layoutNames(list, 0)), { short: 'us', display: 'English (US)', long: 'English (US) layout' });
    assert.deepEqual(j(S.layoutNames(list, 1)), { short: 'de', display: 'de', long: 'de' });
    assert.deepEqual(j(S.layoutNames(list, 2)), { short: '', display: '', long: '' });
});
