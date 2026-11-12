const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/AppMatch.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const find = (entry, tasks) => ctx.findTask(entry, tasks);

const tasks = [
    { appId: 'firefox', launcherUrl: 'file:///usr/share/applications/firefox.desktop', isWindow: true },
    { appId: 'org.telegram.desktop', launcherUrl: 'file:///usr/share/applications/org.telegram.desktop.desktop', isWindow: true },
    { appId: 'spotify', launcherUrl: '', isWindow: true },
];

test('matches by app id, with or without .desktop', () => {
    assert.equal(find('firefox', tasks), 0);
    assert.equal(find('firefox.desktop', tasks), 0);
    assert.equal(find('Spotify', tasks), 2);
});

test('ids that really end in .desktop match their window and launcher file', () => {
    assert.equal(find('org.telegram.desktop', tasks), 1);
    assert.equal(find('org.telegram.desktop.desktop', tasks), 1);
    assert.equal(find('org.telegram.desktop', [{ appId: '', launcherUrl: 'file:///usr/share/applications/org.telegram.desktop.desktop', isWindow: true }]), 0);
});

test('no match, empty values and non-window rows give -1', () => {
    assert.equal(find('org.kde.kate', tasks), -1);
    assert.equal(find('', tasks), -1);
    assert.equal(find(null, tasks), -1);
    assert.equal(find('firefox', []), -1);
    assert.equal(find('firefox', undefined), -1);
    assert.equal(find('firefox', [{ appId: 'firefox', isWindow: false }]), -1);
});

test('a prefix of another id is not a match', () => {
    assert.equal(find('org.telegram', tasks), -1);
});
