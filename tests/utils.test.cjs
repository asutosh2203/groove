const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the helpers as they were in main.qml before they moved.
const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/Utils.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const u = ctx;

test('finiteNumber converts numeric input and falls back otherwise', () => {
    assert.equal(u.finiteNumber('12', 0), 12);
    assert.equal(u.finiteNumber(NaN, 7), 7);
    assert.equal(u.finiteNumber(Infinity, 7), 7);
    assert.equal(u.finiteNumber('abc', 7), 7);
    assert.equal(u.finiteNumber(null, 7), 0); // Number(null) is 0
    assert.equal(u.finiteNumber(undefined, 7), 7);
});

test('clampNumber clamps and tolerates bad bounds', () => {
    assert.equal(u.clampNumber(5, 0, 10), 5);
    assert.equal(u.clampNumber(-5, 0, 10), 0);
    assert.equal(u.clampNumber(50, 0, 10), 10);
    assert.equal(u.clampNumber(5, 10, 0), 10); // max below min collapses to min
    assert.equal(u.clampNumber('x', 2, 10), 2);
});

test('percentFromRatio rounds to a whole percent and never divides by zero', () => {
    assert.equal(u.percentFromRatio(1, 3), 33);
    assert.equal(u.percentFromRatio(50, 100), 50);
    assert.equal(u.percentFromRatio(150, 100), 100);
    assert.equal(u.percentFromRatio(5, 0), 100); // maximum is floored at 1
});

test('firstValidNumber returns the first finite entry', () => {
    assert.equal(u.firstValidNumber([NaN, 'x', 4, 5], -1), 4);
    assert.equal(u.firstValidNumber([NaN, 'x'], -1), -1);
    assert.equal(u.firstValidNumber([], -1), -1);
});

test('hasVisualValue treats blank strings and nullish as empty', () => {
    assert.equal(u.hasVisualValue(undefined), false);
    assert.equal(u.hasVisualValue(null), false);
    assert.equal(u.hasVisualValue('  '), false);
    assert.equal(u.hasVisualValue('a'), true);
    assert.equal(u.hasVisualValue(0), true);
});

test('formatByteSize picks the unit and the decimals', () => {
    assert.equal(u.formatByteSize(0), '0 B');
    assert.equal(u.formatByteSize(1023), '1023 B');
    assert.equal(u.formatByteSize(1536), '1.50 KiB');
    assert.equal(u.formatByteSize(10240), '10.0 KiB');
    assert.equal(u.formatByteSize(150 * 1024 * 1024), '150 MiB');
    assert.equal(u.formatByteSize(-5), '0 B');
    assert.equal(u.formatByteSize('junk'), '0 B');
});

test('shellQuote single-quotes and escapes embedded quotes', () => {
    assert.equal(u.shellQuote('abc'), "'abc'");
    assert.equal(u.shellQuote("it's"), "'it'\"'\"'s'");
    assert.equal(u.shellQuote(undefined), "''");
});
