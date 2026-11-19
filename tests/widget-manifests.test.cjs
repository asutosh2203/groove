const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const { render } = require('../scripts/gen-widgets.cjs');

const ui = path.join(__dirname, '../contents/ui');

test('the generated manifest mirror matches the manifests (CI drift check)', () => {
    assert.equal(fs.readFileSync(path.join(ui, 'widgets/Manifests.js'), 'utf8'), render(), 'run scripts/gen-widgets.cjs and commit the result');
});

test('every built-in manifest is valid', () => {
    const ctx = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(ui, 'logic/WidgetRegistry.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
    vm.runInContext(fs.readFileSync(path.join(ui, 'widgets/Manifests.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
    const reg = JSON.parse(JSON.stringify(ctx.build(vm.runInContext('list', ctx))));
    assert.deepEqual(reg.skipped, []);
    assert.deepEqual(reg.ids.sort(), ['claude-code', 'clock', 'weather', 'world-clock']);
});
