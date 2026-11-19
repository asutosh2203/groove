const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/Concentric.js'), 'utf8');
const m = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), m);

test('the radius is the container radius minus the inset', () => {
    assert.equal(m.radius(14, 4), 10);
    assert.equal(m.radius(26, 12), 14);
});

test('the radius never goes negative when the inset is larger than the container radius', () => {
    assert.equal(m.radius(4, 4), 0);
    assert.equal(m.radius(3, 4), 0);
});

test('a row that fills the container is inset by the full inset', () => {
    assert.equal(m.margin(0, 4), 4);
});

test('a padded row is outset into its padding so the highlight ends `inset` from the container', () => {
    assert.equal(m.margin(10, 4), -6);
    // 10 px of padding plus half a grid gap to a divider
    assert.equal(m.margin(14, 4), -10);
});

test('a row exactly `inset` from the container needs no margin', () => {
    assert.equal(m.margin(4, 4), 0);
});

test('highlight edge lands inset from the container for any gap', () => {
    for (const gap of [0, 2, 4, 10, 14]) {
        // the row edge is `gap` from the container; a positive margin moves the highlight further in
        assert.equal(gap + m.margin(gap, 4), 4);
    }
});
