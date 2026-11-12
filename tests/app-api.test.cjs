const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// The views reach the coordinator as `app` (main.qml's root). `app` is an untyped property, so qmllint cannot tell a
// typo or a renamed member from a real one; this test can. Every `app.<member>` used by a view must be declared on
// main.qml's root (property, alias or function) or be a member PlasmoidItem itself provides.
const ui = path.join(__dirname, '../contents/ui');
const main = fs.readFileSync(path.join(ui, 'main.qml'), 'utf8');

// Members declared at the root level (4-space indent) of main.qml.
const declared = new Set();
for (const m of main.matchAll(/^    (?:readonly |required )?property (?:alias )?(?:\w+(?:<\w+>)?\s+)?(\w+)\s*:/gm)) declared.add(m[1]);
for (const m of main.matchAll(/^    (?:readonly |required )?property (?:\w+(?:<\w+>)?\s+)?(\w+)\s*$/gm)) declared.add(m[1]);
for (const m of main.matchAll(/^    function (\w+)\(/gm)) declared.add(m[1]);
// What PlasmoidItem / Item provide and the views are known to use.
const inherited = new Set(['compactRepresentationItem', 'expanded', 'width', 'height', 'visible', 'x', 'y', 'parent']);

function qmlFiles(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) return e.name === 'services' || e.name === 'logic' ? [] : qmlFiles(p);
        return e.name.endsWith('.qml') && e.name !== 'main.qml' ? [p] : [];
    });
}

test('every app.<member> used by a view exists on main.qml', () => {
    const missing = [];
    for (const file of qmlFiles(ui)) {
        const text = fs.readFileSync(file, 'utf8').replace(/\/\/.*$/gm, '');
        for (const m of text.matchAll(/\bapp\.(\w+)/g)) {
            if (!declared.has(m[1]) && !inherited.has(m[1])) missing.push(`${path.relative(ui, file)}: app.${m[1]}`);
        }
    }
    assert.deepEqual([...new Set(missing)].sort(), []);
});

test('the declared set is not trivially empty (the scan itself works)', () => {
    for (const name of ['media', 'notifications', 'jobs', 'system', 'connectivity', 'launcher', 'layoutService', 'weather', 'hasActivity', 'primaryText', 'closeIsland'])
        assert.ok(declared.has(name), name);
});
