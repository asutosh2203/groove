const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/AppMatch.js'), 'utf8');
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

test('loose matching for raising: a player id that starts a task id, exact matches first, no plain prefixes, never ambiguous', () => {
    const loose = (entry, list) => ctx.findTaskLoose(entry, list);
    const list = [
        { appId: 'spotify-launcher', launcherUrl: 'applications:spotify-launcher.desktop', isWindow: true },
        { appId: 'spotifyd', launcherUrl: '', isWindow: true },
        { appId: 'org.kde.dolphin', launcherUrl: 'applications:org.kde.dolphin.desktop', isWindow: true },
        { appId: 'org.kde.dolphin.extra', launcherUrl: '', isWindow: true },
        { appId: 'firefox', launcherUrl: 'applications:firefox.desktop', isWindow: false }
    ];
    assert.equal(loose('spotify', list), 0);
    assert.equal(loose('Spotify.desktop', list), 0);
    assert.equal(loose('org.kde.dolphin', list), 2);
    assert.equal(loose('spot', list), -1);
    assert.equal(loose('firefox', list), -1);
    assert.equal(loose('', list), -1);
    // two tasks start with the id: ambiguous, so nothing is raised
    const two = [{ appId: 'spotify-launcher', launcherUrl: '', isWindow: true }, { appId: 'spotify.beta', launcherUrl: '', isWindow: true }];
    assert.equal(loose('spotify', two), -1);
    // the same task matching by both of its ids counts once
    assert.equal(loose('spotify', [{ appId: 'spotify-launcher', launcherUrl: 'applications:spotify-launcher.desktop', isWindow: true }]), 0);
});

test('only plain desktop ids that start with a letter or digit pass', () => {
    for (const ok of ['firefox', 'org.telegram.desktop', 'spotify-launcher', '0ad', 'org.kde.dolphin.desktop'])
        assert.equal(ctx.isDesktopId(ok), true, ok);
    for (const bad of ['', null, undefined, '-help', '--version', '.hidden', '_x', 'a b', 'x;rm', '$(id)', 'a/b', '../x', 'a\nb'])
        assert.equal(ctx.isDesktopId(bad), false, String(bad));
});
