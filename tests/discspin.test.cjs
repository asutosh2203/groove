const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const code = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/DiscSpin.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const ctx = vm.createContext({});
vm.runInContext(code, ctx);
const D = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));
const speed = vm.runInContext('degPerSecond', ctx);
const maxGap = vm.runInContext('maxGapMs', ctx);

const ok = { pill: true, playing: true, artworkReady: true, kind: 'music', panelHidden: false, reduceMotion: false };

test('spinWanted needs the Pill, playing music with real art, a visible panel and motion allowed', () => {
    assert.equal(D.spinWanted(ok), true);
    for (const [k, v] of [['pill', false], ['playing', false], ['artworkReady', false], ['kind', 'video'], ['kind', 'other'], ['panelHidden', true], ['reduceMotion', true]])
        assert.equal(D.spinWanted({ ...ok, [k]: v }), false, k);
    assert.equal(D.spinWanted({}), false);
});

test('a spinning disc advances by degrees per second', () => {
    const a = D.step(D.initial(), { key: 't1', spinning: true }, 1000);
    assert.deepEqual(j(a), { key: 't1', angle: 0, at: 1000, spinning: true });
    const b = D.step(a, { key: 't1', spinning: true }, 1500);
    assert.equal(b.angle, speed * 0.5);
});

test('pausing holds the angle and playing again resumes from it', () => {
    let h = D.step(D.initial(), { key: 't1', spinning: true }, 0);
    h = D.step(h, { key: 't1', spinning: true }, 500);
    const at = h.angle;
    h = D.step(h, { key: 't1', spinning: false }, 600);
    assert.equal(h.angle, at);
    h = D.step(h, { key: 't1', spinning: false }, 900);
    assert.equal(h.angle, at);
    h = D.step(h, { key: 't1', spinning: true }, 5000);
    assert.equal(h.angle, at);
    h = D.step(h, { key: 't1', spinning: true }, 5100);
    assert.ok(Math.abs(h.angle - (at + speed * 0.1)) < 1e-9);
});

test('a new track starts at angle 0, held or spinning', () => {
    let h = { key: 't1', angle: 123, at: 0, spinning: true };
    assert.equal(D.step(h, { key: 't2', spinning: true }, 100).angle, 0);
    assert.equal(D.step({ ...h, spinning: false }, { key: 't2', spinning: false }, 100).angle, 0);
    assert.equal(D.angleFor(h, 't1'), 123);
    assert.equal(D.angleFor(h, 't2'), 0);
});

test('the angle wraps to 0-360', () => {
    const h = D.step({ key: 't', angle: 359, at: 0, spinning: true }, { key: 't', spinning: true }, 500);
    assert.ok(h.angle >= 0 && h.angle < 360);
    assert.ok(Math.abs(h.angle - ((359 + speed * 0.5) % 360)) < 1e-9);
});

test('a long gap is not caught up on', () => {
    const h = { key: 't', angle: 10, at: 0, spinning: true };
    assert.equal(D.step(h, { key: 't', spinning: true }, maxGap + 1).angle, 10);
    assert.equal(D.step(h, { key: 't', spinning: true }, maxGap).angle, 10 + speed * maxGap / 1000);
    assert.equal(D.step(h, { key: 't', spinning: true }, -50).angle, 10);
});
