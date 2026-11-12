const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/FullscreenState.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const covering = (tasks) => ctx.covering(tasks);

test('no windows, or only normal windows, do not cover', () => {
    assert.equal(covering([]), false);
    assert.equal(covering(undefined), false);
    assert.equal(covering([{ isWindow: true, fullScreen: false, minimized: false }]), false);
});

test('a visible fullscreen window covers', () => {
    assert.equal(covering([{ isWindow: true, fullScreen: false }, { isWindow: true, fullScreen: true, minimized: false }]), true);
});

test('a minimized fullscreen window does not cover', () => {
    assert.equal(covering([{ isWindow: true, fullScreen: true, minimized: true }]), false);
});

test('non-window rows and garbage entries are ignored', () => {
    assert.equal(covering([{ isWindow: false, fullScreen: true }, null, undefined, {}]), false);
    assert.equal(covering([{ fullScreen: 'yes' }]), false);
});
