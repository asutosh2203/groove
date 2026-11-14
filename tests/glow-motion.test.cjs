const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const src = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/GlowMotion.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const ctx = vm.createContext({ Math });
vm.runInContext(src, ctx);
const G = ctx;
const cfg = { tauMs: 23, fadeMs: 350, settlePx: 0.3 };
const j = (v) => JSON.parse(JSON.stringify(v));
const run = (state, input, ms, hz) => {
    const dt = 1000 / hz;
    let s = state;
    let t = 0;
    for (; t + dt <= ms + 1e-9; t += dt) s = j(G.advance(s, input, dt, cfg));
    if (ms - t > 1e-9) s = j(G.advance(s, input, ms - t, cfg)); // the remainder, so every rate covers exactly ms
    return s;
};

test('smoothing covers the same distance in the same real time at any frame rate', () => {
    const at = (hz) => run({ x: 0, y: 0, s: 1 }, { tx: 100, ty: 0, hover: true, off: false }, 46, hz).x;
    for (const hz of [30, 60, 144, 165, 240]) assert.ok(Math.abs(at(hz) - at(60)) < 0.6, 'hz ' + hz);
    // after 2 time constants about 86.5% of the way
    assert.ok(Math.abs(at(165) - 86.47) < 0.6);
});

test('the glow settles on the pointer and then asks for no more frames', () => {
    const input = { tx: 40, ty: 25, hover: true, off: false };
    const s = run({ x: 0, y: 0, s: 1 }, input, 600, 165);
    assert.equal(s.x, 40);
    assert.equal(s.y, 25);
    assert.equal(G.needsFrames(s, input, cfg), false);
});

test('a pointer that moves makes it need frames; a resting one does not', () => {
    const rest = { x: 50, y: 50, s: 1 };
    assert.equal(G.needsFrames(rest, { tx: 50, ty: 50, hover: true, off: false }, cfg), false);
    assert.equal(G.needsFrames(rest, { tx: 80, ty: 50, hover: true, off: false }, cfg), true);
    assert.equal(G.needsFrames(rest, { tx: 50.2, ty: 50.2, hover: true, off: false }, cfg), false);
});

test('fade in about 350 ms, fade out on leave, then no frames', () => {
    const inside = { tx: 10, ty: 10, hover: true, off: false };
    let s = run({ x: 10, y: 10, s: 0 }, inside, 175, 165);
    assert.ok(s.s > 0.4 && s.s < 0.6, 'half way at 175 ms: ' + s.s);
    s = run(s, inside, 200, 165);
    assert.equal(s.s, 1);
    assert.equal(G.needsFrames(s, inside, cfg), false);
    const outside = { tx: 10, ty: 10, hover: false, off: false };
    assert.equal(G.needsFrames(s, outside, cfg), true);
    s = run(s, outside, 400, 165);
    assert.equal(s.s, 0);
    assert.equal(G.needsFrames(s, outside, cfg), false);
});

test('re-entering after a full fade-out starts at the pointer, not at the old spot', () => {
    const s = j(G.advance({ x: 300, y: 20, s: 0 }, { tx: 5, ty: 6, hover: true, off: false }, 6, cfg));
    assert.equal(s.x, 5);
    assert.equal(s.y, 6);
    assert.ok(s.s > 0);
});

test('with animations off the glow jumps: no follow, no fade', () => {
    const on = j(G.advance({ x: 0, y: 0, s: 0 }, { tx: 90, ty: 40, hover: true, off: true }, 6, cfg));
    assert.deepEqual(on, { x: 90, y: 40, s: 1 });
    const off = j(G.advance(on, { tx: 90, ty: 40, hover: false, off: true }, 6, cfg));
    assert.equal(off.s, 0);
    assert.equal(G.needsFrames(off, { tx: 90, ty: 40, hover: false, off: true }, cfg), false);
});

test('eased fade has soft ends; animationsOff reads Kirigami durations', () => {
    assert.equal(G.eased(0), 0);
    assert.equal(G.eased(1), 1);
    assert.equal(G.eased(0.5), 0.5);
    assert.ok(G.eased(0.1) < 0.1);
    assert.equal(G.animationsOff(1), true);
    assert.equal(G.animationsOff(0), true);
    assert.equal(G.animationsOff(50), false);
    assert.equal(G.animationsOff(200), false);
});
