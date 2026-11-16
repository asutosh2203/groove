const assert = require('node:assert/strict');
const path = require('node:path');
const { test } = require('node:test');
const T = require('../scripts/check-tokens.cjs');

const root = path.join(__dirname, '..');
const c = (text) => T.count(text);

test('counts each kind of hardcoded literal and ignores tokens, expressions, comments, zero and 0/1 opacity', () => {
    assert.equal(c('Rectangle {\n    radius: 12\n}').radius, 1);
    assert.equal(c('Rectangle {\n    radius: T.radiusInner\n}').radius, 0);
    assert.equal(c('Text {\n    font.pixelSize: 9\n}').font, 1);
    assert.equal(c('Text {\n    font.pixelSize: T.fontCaption\n}').font, 0);
    assert.equal(c('RowLayout {\n    spacing: 8\n    spacing: 0\n    spacing: gap\n}').spacing, 1);
    assert.equal(c('Item {\n    anchors.margins: 7\n    Layout.topMargin: 4\n    anchors.leftMargin: 0\n}').margin, 2);
    assert.equal(c('Item {\n    opacity: 0.45\n    opacity: 1\n    opacity: 0\n    opacity: enabled ? 1 : 0.5\n}').opacity, 1);
    assert.equal(c('    // radius: 12\n').radius, 0);
});

test('motion: a duration, a timer interval and an easing on one line all count', () => {
    assert.equal(c('Behavior on x { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }').motion, 2);
    assert.equal(c('Behavior on x { NumberAnimation { duration: T.motionFast; easing.type: T.easingStandard } }').motion, 0);
    assert.equal(c('Timer {\n    interval: 1000\n}').motion, 1);
});

test('icon sizes count inside icon items and as glyphSize, not on other items', () => {
    assert.equal(c('Kirigami.Icon {\n    width: 24\n    height: 24\n}').icon, 2);
    assert.equal(c('Item {\n    width: 24\n    height: 24\n}').icon, 0);
    assert.equal(c('IslandButton {\n    glyphSize: 17\n}').icon, 1);
    assert.equal(c('Kirigami.Icon {\n    width: parent.width\n}\nItem {\n    width: 5\n}').icon, 0);
});

test('no file has more hardcoded layout or motion literals than its baseline (D-47)', () => {
    const counts = T.countAll(root);
    const baseline = T.readBaseline(path.join(root, '.github/token-baseline.txt'));
    const bad = T.over(counts, baseline);
    assert.deepEqual(bad, [], 'use the tokens in controlcenter/Tokens.js; counts only go down (node scripts/check-tokens.cjs --lower-baseline)');
});

test('a file with no baseline entry may not have any literal', () => {
    assert.deepEqual(T.over({ 'contents/ui/New.qml': 1 }, {}), [{ file: 'contents/ui/New.qml', count: 1, baseline: 0 }]);
    assert.deepEqual(T.over({ 'contents/ui/Old.qml': 3 }, { 'contents/ui/Old.qml': 3 }), []);
});
