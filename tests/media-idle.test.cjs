const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/MediaIdle.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const reduce = (s, e) => JSON.parse(JSON.stringify(ctx.reduce(s, e)));
const shown = (h, p, x) => ctx.shown(h, p, x);

test('playing shows media at once and cancels any pending timeout', () => {
    assert.deepEqual(reduce({ expired: true }, 'playing'), { expired: false, scheduleMs: null });
});

test('stopping starts the 30 s grace period without hiding media yet', () => {
    assert.deepEqual(reduce({ expired: false }, 'notPlaying'), { expired: false, scheduleMs: 30000 });
});

test('the timeout hands the island back to the idle face', () => {
    assert.deepEqual(reduce({ expired: false }, 'timeout'), { expired: true, scheduleMs: null });
});

test('a player that disappears resets everything', () => {
    assert.deepEqual(reduce({ expired: true }, 'gone'), { expired: false, scheduleMs: null });
});

test('an unknown event changes nothing', () => {
    assert.deepEqual(reduce({ expired: true }, 'bogus'), { expired: true, scheduleMs: null });
    assert.deepEqual(reduce(undefined, 'bogus'), { expired: false, scheduleMs: null });
});

test('media is shown while playing, and while paused until the grace period ends', () => {
    assert.equal(shown(true, true, false), true);
    assert.equal(shown(true, true, true), true);     // playing always wins, even if a stale timeout fired
    assert.equal(shown(true, false, false), true);   // paused, still inside the grace period
    assert.equal(shown(true, false, true), false);   // paused past 30 s: idle face
});

test('no player means no media activity', () => {
    assert.equal(shown(false, false, false), false);
    assert.equal(shown(false, true, false), false);
    assert.equal(shown(undefined, true, false), false);
});

test('pause, wait 30 s, play: the sequence the live test walks through', () => {
    let st = { expired: false };
    let r = reduce(st, 'playing');             st = r; assert.equal(shown(true, true, st.expired), true);
    r = reduce(st, 'notPlaying');              st = { expired: r.expired }; assert.equal(r.scheduleMs, 30000); assert.equal(shown(true, false, st.expired), true);
    r = reduce(st, 'timeout');                 st = r; assert.equal(shown(true, false, st.expired), false);
    r = reduce(st, 'playing');                 st = r; assert.equal(shown(true, true, st.expired), true);
});
