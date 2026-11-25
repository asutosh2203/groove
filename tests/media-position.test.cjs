const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/MediaPosition.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const step = (h, i, now) => JSON.parse(JSON.stringify(ctx.step(h, Object.assign({ key: 'a', playing: true, reported: 0, rate: 1, browser: true, length: 0 }, i), now)));

test('a reported position is shown as is', () => {
    assert.equal(step(null, { reported: 5e6 }, 1000).pos, 5e6);
});

test('a browser 0 while playing advances from the last position at the rate', () => {
    const h = step(null, { reported: 600e6, rate: 1 }, 0);
    assert.equal(step(h, { reported: 0 }, 28000).pos, 628e6);
});

test('the rate scales the estimate', () => {
    const h = step(null, { reported: 31e6, rate: 3 }, 0);
    assert.equal(step(h, { reported: 0, rate: 3 }, 4000).pos, 43e6);
});

test('a browser 0 while paused holds the position', () => {
    const h = step(null, { reported: 85e6, playing: false }, 0);
    assert.equal(step(h, { reported: 0, playing: false }, 9000).pos, 85e6);
});

test('resuming with a 0 starts counting from the paused position', () => {
    let h = step(null, { reported: 85e6, playing: false }, 0);
    h = step(h, { reported: 0, playing: true }, 5000);
    assert.equal(h.pos, 85e6);
    assert.equal(step(h, { reported: 0 }, 7000).pos, 87e6);
});

test('a non-browser 0 is a real 0', () => {
    const h = step(null, { reported: 50e6, browser: false }, 0);
    assert.equal(step(h, { reported: 0, browser: false }, 2000).pos, 0);
});

test('a new track does not inherit the old position', () => {
    const h = step(null, { reported: 50e6 }, 0);
    assert.equal(step(h, { key: 'b', reported: 0 }, 2000).pos, 0);
});

test('the estimate never passes the length', () => {
    const h = step(null, { reported: 99e6, length: 100e6 }, 0);
    assert.equal(step(h, { reported: 0, length: 100e6 }, 60000).pos, 100e6);
});

test('a missing rate counts as 1', () => {
    const h = step(null, { reported: 10e6, rate: 0 }, 0);
    assert.equal(step(h, { reported: 0, rate: 0 }, 2000).pos, 12e6);
});

const vis = (o) => ctx.readoutVisible(Object.assign({ deckMode: true, dialogVisible: false, islandOpen: false, activityPopup: false, popupActivityIsMedia: false, panelHidden: false, compactIsMedia: true }, o));

test('a closed deck falls through to the compact media pill', () => {
    assert.equal(vis({}), true);
    assert.equal(vis({ compactIsMedia: false }), false);
    assert.equal(vis({ panelHidden: true }), false);
});

test('an open deck and a media activity popup show the readout', () => {
    assert.equal(vis({ dialogVisible: true, islandOpen: true, compactIsMedia: false }), true);
    assert.equal(vis({ deckMode: false, activityPopup: true, islandOpen: true, popupActivityIsMedia: true, compactIsMedia: false }), true);
    assert.equal(vis({ deckMode: false, activityPopup: true, islandOpen: true, popupActivityIsMedia: false }), false);
});
