const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/Accordion.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);

test('toggle: opens, swaps and closes', () => {
    assert.equal(ctx.toggle('', 'a'), 'a');
    assert.equal(ctx.toggle('a', 'b'), 'b');
    assert.equal(ctx.toggle('a', 'a'), '');
});

test('clamp: the open row is kept while its job is in the list, else nothing is open', () => {
    assert.equal(ctx.clamp('a', ['b', 'a']), 'a');
    assert.equal(ctx.clamp('a', ['b']), '');
    assert.equal(ctx.clamp('', ['a']), '');
    assert.equal(ctx.clamp('a', []), '');
});
