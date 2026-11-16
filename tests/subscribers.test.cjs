const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/Subscribers.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const s = ctx;
const GRACE = vm.runInContext('GRACE_MS', ctx);

test('a fresh state is idle', () => {
    assert.equal(s.isActive(s.create(), 0), false);
});

test('active while any subscriber remains', () => {
    const two = s.add(s.add(s.create()));
    const one = s.remove(two, 1000);
    assert.equal(one.count, 1);
    assert.equal(s.isActive(one, 10 ** 9), true);
    assert.equal(s.graceLeft(one, 1000), 0);
});

test('the last leaver starts the grace, which then expires', () => {
    const gone = s.remove(s.add(s.create()), 1000);
    assert.equal(s.isActive(gone, 1000 + GRACE - 1), true);
    assert.equal(s.graceLeft(gone, 1000 + 5000), GRACE - 5000);
    assert.equal(s.isActive(gone, 1000 + GRACE), false);
    assert.equal(s.graceLeft(gone, 1000 + GRACE), 0);
});

test('resubscribing inside the grace cancels it', () => {
    const back = s.add(s.remove(s.add(s.create()), 0));
    assert.equal(back.graceUntil, 0);
    assert.equal(s.isActive(back, GRACE * 10), true);
});

test('an unbalanced remove never goes negative', () => {
    assert.equal(s.remove(s.create(), 0).count, 0);
});
