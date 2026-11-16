const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const src = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/GlowMotion.js'), 'utf8').replace('.pragma library', '');
const G = vm.createContext({ Math });
vm.runInContext(src, G);

test('bloom springs past the base, holds, dissolves outward to nothing and ends', () => {
    let s = G.bloomStart(0.05);
    let peakI = 0, peakR = 0, phases = new Set(), t = 0;
    while (G.bloomActive(s) && t < 5000) {
        s = G.bloomAdvance(s, 16); t += 16;
        peakI = Math.max(peakI, s.i); peakR = Math.max(peakR, s.r); phases.add(s.phase);
        assert.ok(s.i >= 0, 'intensity never goes negative');
    }
    assert.ok(!G.bloomActive(s), 'bloom ends');
    assert.ok(t < 3500, 'and in a bounded time: ' + t);
    assert.deepEqual([...phases].sort(), ['dissolve', 'done', 'hold', 'spring']);
    assert.ok(peakI >= 0.058 && peakI < 0.07, 'intensity reaches about 6%: ' + peakI);
    assert.ok(peakR >= 1.6 && peakR < 2.7, 'radius reaches +60% and beyond: ' + peakR);
});

test('bloom frame time is clamped, so a long stall cannot skip the animation', () => {
    const s = G.bloomAdvance(G.bloomStart(0.05), 10000);
    assert.equal(s.phase === 'done', false);
});
