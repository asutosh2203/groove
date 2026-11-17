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

test('scroll target: unchanged when the open row fits, otherwise just enough to show it', () => {
    const ids = ['a', 'b', 'c', 'd', 'e'];
    // rows 30 + gap 8, open row 86, view 100
    assert.equal(ctx.scrollTarget(ids, 'a', 0, 100, 30, 86, 8), 0);
    assert.equal(ctx.scrollTarget(ids, 'e', 0, 100, 30, 86, 8), 152 + 86 - 100);
    assert.equal(ctx.scrollTarget(ids, 'a', 120, 100, 30, 86, 8), 0);
    assert.equal(ctx.scrollTarget(ids, 'zzz', 40, 100, 30, 86, 8), 40);
    assert.equal(ctx.scrollTarget(ids, 'b', 20, 100, 30, 86, 8), 24);
    assert.equal(ctx.scrollTarget(ids, 'b', 30, 100, 30, 86, 8), 30);
});
