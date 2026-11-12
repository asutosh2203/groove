const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/Countdown.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const c = ctx;

test('a running countdown reports the time left', () => {
    const s = c.start(1000, 4000);
    assert.equal(c.remaining(s, 1000), 4000);
    assert.equal(c.remaining(s, 2500), 2500);
    assert.equal(c.remaining(s, 9000), 0);
});

test('pausing freezes the remaining time however long it stays paused', () => {
    const paused = c.pause(c.start(0, 4000), 1500);
    assert.equal(c.remaining(paused, 1500), 2500);
    assert.equal(c.remaining(paused, 60000), 2500);
});

test('resuming continues with the remaining time, not a full restart', () => {
    const paused = c.pause(c.start(0, 4000), 1500);
    const resumed = c.resume(paused, 20000);
    assert.equal(c.remaining(resumed, 20000), 2500);
    assert.equal(c.remaining(resumed, 21000), 1500);
    assert.equal(resumed.endsAt, 22500);
});

test('pause and resume are idempotent and null-safe', () => {
    const s = c.start(0, 1000);
    const p = c.pause(s, 400);
    assert.deepEqual(JSON.parse(JSON.stringify(c.pause(p, 900))), JSON.parse(JSON.stringify(p)));
    assert.equal(c.resume(s, 100), s);
    assert.equal(c.pause(null, 0), null);
    assert.equal(c.resume(undefined, 0), undefined);
    assert.equal(c.remaining(null, 0), 0);
});

test('several pauses add up: only running time is spent', () => {
    let s = c.start(0, 4000);
    s = c.pause(s, 1000);      // 3000 left
    s = c.resume(s, 5000);
    s = c.pause(s, 6000);      // 2000 left
    s = c.resume(s, 9000);
    assert.equal(c.remaining(s, 9500), 1500);
});

test('pausing after expiry leaves nothing and bad durations clamp to zero', () => {
    assert.equal(c.remaining(c.pause(c.start(0, 1000), 5000), 5000), 0);
    assert.equal(c.remaining(c.start(0, -50), 0), 0);
    assert.equal(c.remaining(c.start(0, 'abc'), 0), 0);
});
