const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// D-40: the widget never applies a theme. Applying one rewrites the whole desktop look (colour scheme, widget style, cursor,
// window decoration, GTK files) and is not reversible on a customised setup, so no code path may do it: the "Theme settings"
// tile only opens System Settings. This scans every QML and JS file under contents/ for anything that could apply or write
// a theme, so a future change cannot add it without this test failing.
const root = path.join(__dirname, '../contents');
const forbidden = [
    [/DarkModeControl/, 'the Plasma dark-mode control (it applies a global theme)'],
    [/\bdarkMode\b|setDarkMode/, 'a dark-mode switch'],
    [/plasma-apply-[a-z]+/, 'a plasma-apply-* tool'],
    [/lookandfeeltool/, 'lookandfeeltool'],
    [/plasma-changeicons/, 'plasma-changeicons'],
    [/kwriteconfig\d*/, 'writing a KDE config key'],
    [/LookAndFeelPackage|DefaultLightLookAndFeel|DefaultDarkLookAndFeel|AutomaticLookAndFeel/, 'the look-and-feel settings keys'],
];

function files(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
        const f = path.join(dir, e.name);
        if (e.isDirectory()) return files(f);
        return /\.(qml|js)$/.test(e.name) ? [f] : [];
    });
}

test('no code under contents/ can apply or write a theme', () => {
    const offenders = [];
    for (const file of files(root)) {
        fs.readFileSync(file, 'utf8').split('\n').forEach((line, n) => {
            const code = line.replace(/\/\/.*$/, '');
            for (const [re, what] of forbidden) {
                if (re.test(code)) offenders.push(`${path.relative(root, file)}:${n + 1}: ${what}`);
            }
        });
    }
    assert.deepEqual(offenders, []);
});

test('the only way the widget touches themes is opening the Global Theme settings page', () => {
    const launcher = fs.readFileSync(path.join(root, 'ui/services/AppLauncher.qml'), 'utf8');
    assert.match(launcher, /runner\.run\("kcmshell6 kcm_lookandfeel"\)/);
});

test('the tile keeps its module id so saved layouts still work, with the new label', () => {
    const source = fs.readFileSync(path.join(root, 'ui/logic/ModuleRegistry.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
    const ctx = vm.createContext({ Object, Array });
    vm.runInContext(source, ctx);
    const info = JSON.parse(JSON.stringify(ctx.info('appearanceMode')));
    assert.equal(info.id, 'appearanceMode');
    assert.equal(info.name, 'Theme settings');
    assert.ok(JSON.parse(JSON.stringify(ctx.allModules())).some((m) => m.id === 'appearanceMode'));
    // a layout saved before the rename still sanitises to the same module
    assert.equal(JSON.parse(JSON.stringify(ctx.defaultSize('appearanceMode'))).id, 'appearanceMode');
});
