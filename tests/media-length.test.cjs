const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/MediaLength.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const hold = (h, k, l) => JSON.parse(JSON.stringify(ctx.hold(h, k, l)));

test('a reported length is kept', () => {
    assert.deepEqual(hold(null, 'a', 100), { key: 'a', length: 100 });
});

test('a dropped length (seek) keeps the last one for the same track', () => {
    assert.deepEqual(hold({ key: 'a', length: 100 }, 'a', 0), { key: 'a', length: 100 });
});

test('a new track without a length starts at 0', () => {
    assert.deepEqual(hold({ key: 'a', length: 100 }, 'b', 0), { key: 'b', length: 0 });
});

test('a new length replaces the old one', () => {
    assert.deepEqual(hold({ key: 'a', length: 100 }, 'a', 200), { key: 'a', length: 200 });
});
