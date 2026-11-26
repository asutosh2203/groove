const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const T = load('Tour.js');

test('the tour shows while the stored version is below the current one', () => {
    assert.equal(T.shouldShow({ tourVersion: 0 }), true);
    assert.equal(T.shouldShow({ tourVersion: T.version() }), false);
    assert.equal(T.shouldShow({ tourVersion: T.version() + 3 }), false);
});

test('a later release shows the tour again only to users below it', () => {
    assert.equal(T.shouldShow({ tourVersion: 1, version: 2 }), true);
    assert.equal(T.shouldShow({ tourVersion: 2, version: 2 }), false);
});

test('a missing or odd stored value counts as never shown', () => {
    for (const bad of [undefined, null, 'x', 1.5, NaN, -1])
        assert.equal(T.shouldShow({ tourVersion: bad }), true, String(bad));
});

test('five steps in the agreed order', () => {
    assert.deepEqual(j(T.steps()), ['island', 'live', 'deck', 'customize', 'gestures']);
    assert.equal(T.count(), 5);
});

test('navigation stops at both ends and ignores junk', () => {
    assert.equal(T.back(0), 0);
    assert.equal(T.next(4), 4);
    assert.equal(T.next(0), 1);
    assert.equal(T.back(3), 2);
    assert.equal(T.next(undefined), 1);
    assert.equal(T.clamp(99), 4);
    assert.equal(T.clamp(-5), 0);
});

test('the footer view: counter, Back only after the first step, Done on the last', () => {
    assert.deepEqual(j(T.view(0)), { id: 'island', icons: ['weather-few-clouds-symbolic', 'clock-symbolic', 'window-symbolic'], n: 1, total: 5, canBack: false, primary: 'next' });
    assert.deepEqual(j(T.view(1)), { id: 'live', icons: ['notifications-symbolic', 'media-playback-start-symbolic'], n: 2, total: 5, canBack: true, primary: 'next' });
    assert.deepEqual(j(T.view(4)), { id: 'gestures', icons: ['input-mouse-symbolic', 'configure-symbolic'], n: 5, total: 5, canBack: true, primary: 'done' });
});

test('every step has an icon chain that ends on a Breeze name', () => {
    const breezeLast = ['window-symbolic', 'media-playback-start-symbolic', 'edit-symbolic', 'configure-symbolic'];
    for (const id of T.steps()) {
        const icons = j(T.view(T.steps().indexOf(id)).icons);
        assert.ok(icons.length >= 2, id);
        assert.ok(breezeLast.includes(icons.at(-1)), id);
        assert.ok(icons.every(n => n.endsWith('-symbolic')), id);
    }
});
