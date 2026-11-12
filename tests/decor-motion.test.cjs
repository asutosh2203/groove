const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/DecorMotion.js'), 'utf8');
const m = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), m);
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) <= eps, `${a} is not within ${eps} of ${b}`);

test('inOutSine is 0 at the start, 0.5 in the middle, 1 at the end and clamps', () => {
    near(m.inOutSine(0), 0);
    near(m.inOutSine(0.5), 0.5);
    near(m.inOutSine(1), 1);
    near(m.inOutSine(-3), 0);
    near(m.inOutSine(9), 1);
});

test('a bar cycle rests for the delay, dips to the low value and returns', () => {
    // AudioBars bar 2: hi 0.58, lo max(0.35, 1 - 0.58 * 0.25), delay 110, d1 480, d2 530
    const lo = Math.max(0.35, 1 - 0.58 * 0.25);
    near(m.cycle(0, 110, 480, 530, 0.58, lo), 0.58);
    near(m.cycle(100, 110, 480, 530, 0.58, lo), 0.58);               // still resting
    near(m.cycle(110 + 480, 110, 480, 530, 0.58, lo), lo);           // bottom of the dip
    near(m.cycle(110 + 480 + 530, 110, 480, 530, 0.58, lo), 0.58);   // back at the top
    near(m.cycle(1120 + 110 + 480, 110, 480, 530, 0.58, lo), lo);    // and it repeats
});

test('cycle stays between its two values and handles negative time', () => {
    for (let t = -3000; t < 3000; t += 37) {
        const v = m.cycle(t, 55, 400, 440, 0.4, 0.9);
        assert.ok(v >= 0.4 - 1e-9 && v <= 0.9 + 1e-9, `t=${t} v=${v}`);
    }
});

test('phase wraps cleanly', () => {
    near(m.phase(0, 1700), 0);
    near(m.phase(850, 1700), 0.5);
    near(m.phase(1700, 1700), 0);
    near(m.phase(-850, 1700), 0.5);
});

test('sway swings between its two values over two halves', () => {
    near(m.sway(0, 3200, -0.09, 0.09), -0.09);
    near(m.sway(3200, 3200, -0.09, 0.09), 0.09);
    near(m.sway(6400, 3200, -0.09, 0.09), -0.09);
});

test('the bolt is full for 2.6 s, flashes down, stutters and is full again', () => {
    near(m.bolt(0), 1);
    near(m.bolt(2000), 1);
    near(m.bolt(2600 + 60), 0.15);          // first dip bottom
    near(m.bolt(2600 + 60 + 70), 1);        // back up
    near(m.bolt(2600 + 60 + 70 + 60), 0.35);
    near(m.bolt(2930), 1);                  // end of the cycle wraps to the start
    for (let t = 0; t < 6000; t += 11)
        assert.ok(m.bolt(t) >= 0.15 - 1e-9 && m.bolt(t) <= 1 + 1e-9);
});
