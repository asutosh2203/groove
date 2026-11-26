const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const root = path.join(__dirname, '..');
const json = (rel) => JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));
const template = path.join('extras', 'layout-template');
const templateDir = fs.readdirSync(path.join(root, template))[0];

test('the layout template adds the widget that metadata.json declares (D-66)', () => {
    const id = json('metadata.json').KPlugin.Id;
    const layout = fs.readFileSync(path.join(root, template, templateDir, 'contents', 'layout.js'), 'utf8');
    assert.ok(layout.includes(`panel.addWidget("${id}")`), `layout.js must add ${id}`);
});

test('the layout template id is the widget id plus ".panel" and matches its folder', () => {
    const id = json('metadata.json').KPlugin.Id;
    const tpl = json(path.join(template, templateDir, 'metadata.json')).KPlugin;
    assert.equal(tpl.Id, `${id}.panel`);
    assert.equal(templateDir, tpl.Id);
});

// D-66/D-67: the upstream ID and the old package name must not creep back. History (docs, CHANGELOG)
// and the upstream project link are exempt: the upstream URL has no "com.manu028" or "dynamicisland".
test('the old upstream plugin id and package name appear nowhere in shipped files', () => {
    const banned = ['com.manu028', 'dynamicisland', 'dynamic-island-'];
    const files = ['metadata.json', 'README.md', 'RELEASE_CHECKLIST.md', 'REUSE.toml', 'assets', 'contents', 'extras',
        'integrations', 'scripts', 'tests', '.github'];
    const self = path.basename(__filename);
    const hits = [];
    const walk = (p) => {
        const full = path.join(root, p);
        if (fs.statSync(full).isDirectory()) return fs.readdirSync(full).forEach((f) => walk(path.join(p, f)));
        if (path.basename(p) === self || p.endsWith('__pycache__')) return;
        const text = fs.readFileSync(full);
        if (text.includes(0)) return;
        banned.filter((b) => text.toString('utf8').includes(b)).forEach((b) => hits.push(`${p}: ${b}`));
    };
    files.forEach(walk);
    assert.deepEqual(hits, []);
});
