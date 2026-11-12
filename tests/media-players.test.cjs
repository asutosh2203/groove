const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the player-selection code as it was in main.qml before it moved.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const uctx = vm.createContext({ isFinite, Number, Math });
vm.runInContext(read('Utils.js'), uctx);
const ctx = vm.createContext({ Utils: { finiteNumber: uctx.finiteNumber }, isFinite, Number, Math, String });
vm.runInContext(read('MediaPlayers.js'), ctx);
const S = { playing: 2, paused: 3, stopped: 4 };
const j = (v) => JSON.parse(JSON.stringify(v));
const player = (o) => ({ playbackStatus: S.playing, track: '', artist: '', album: '', artUrl: '', length: 0, identity: '', desktopEntry: '', canControl: false, canPlay: false, canPause: false, ...o });
const score = (p) => ctx.score(p, S);

const spotifyPlaying = player({ identity: 'Spotify', track: 'Song', artist: 'Band', album: 'LP', artUrl: 'x', length: 1e8, canControl: true, canPlay: true });
const firefoxPaused = player({ playbackStatus: S.paused, identity: 'Mozilla Firefox', desktopEntry: 'firefox', track: 'Video', artist: 'Chan', length: 1e9, canControl: true, canPlay: true });

test('a stopped player never scores', () => {
    assert.equal(score(player({ playbackStatus: S.stopped, track: 'x' })), -1);
    assert.equal(score(null), -1);
    assert.equal(score(undefined), -1);
});

test('a paused player with no metadata is not worth showing, a playing one is', () => {
    assert.equal(score(player({ playbackStatus: S.paused })), -1);
    assert.equal(score(player({ playbackStatus: S.playing })), 1000);
});

test('the score adds up: status, then each piece of metadata and control', () => {
    assert.equal(score(spotifyPlaying), 1000 + 80 + 45 + 20 + 20 + 25 + 10 + 10);
    assert.equal(score(firefoxPaused), 500 + 80 + 45 + 25 + 10 + 10);
});

test('a browser that has no metadata is pushed down hard', () => {
    const bare = player({ identity: 'Google Chrome', canControl: true, canPlay: true });
    assert.equal(score(bare), 1000 + 10 + 10 - 400);
    assert.equal(ctx.isBrowserish(player({ desktopEntry: 'vivaldi-stable' })), true);
    assert.equal(ctx.isBrowserish(player({ identity: 'Spotify' })), false);
});

test('playing beats paused, whatever the metadata', () => {
    const r = j(ctx.pick([firefoxPaused, spotifyPlaying], null, S));
    assert.deepEqual(r, { source: 'candidate', index: 1 });
    const r2 = j(ctx.pick([player({ playbackStatus: S.playing, track: 'a' }), firefoxPaused], null, S));
    assert.deepEqual(r2, { source: 'candidate', index: 0 });
});

test('two equal players: the first one wins the tie', () => {
    const a = player({ track: 'same' });
    const b = player({ track: 'same' });
    assert.deepEqual(j(ctx.pick([a, b], null, S)), { source: 'candidate', index: 0 });
});

test('the fallback wins only when it scores strictly higher than every candidate', () => {
    assert.deepEqual(j(ctx.pick([firefoxPaused], spotifyPlaying, S)), { source: 'fallback' });
    assert.deepEqual(j(ctx.pick([spotifyPlaying], spotifyPlaying, S)), { source: 'candidate', index: 0 });
    assert.deepEqual(j(ctx.pick([], spotifyPlaying, S)), { source: 'fallback' });
});

test('nothing worth showing gives none', () => {
    assert.deepEqual(j(ctx.pick([], null, S)), { source: 'none' });
    assert.deepEqual(j(ctx.pick([player({ playbackStatus: S.stopped }), null, player({ playbackStatus: S.paused })], player({ playbackStatus: S.stopped }), S)), { source: 'none' });
});

test('text collapses whitespace and tolerates nullish', () => {
    assert.equal(ctx.text('  a   b\n c '), 'a b c');
    assert.equal(ctx.text(null), '');
    assert.equal(ctx.text(undefined), '');
});

test('times read as m:ss from microseconds and survive junk', () => {
    assert.equal(ctx.formatTime(0), '0:00');
    assert.equal(ctx.formatTime(59e6), '0:59');
    assert.equal(ctx.formatTime(61e6), '1:01');
    assert.equal(ctx.formatTime(3600e6), '60:00');
    assert.equal(ctx.formatTime(-1), '0:00');
    assert.equal(ctx.formatTime('junk'), '0:00');
    assert.equal(ctx.formatProgress(61e6, 270680000), '1:01 / 4:30');
});

test('lengthKey ties a length to one track on one player', () => {
    assert.equal(ctx.lengthKey(spotifyPlaying), 'Spotify|Song|Band');
    assert.equal(ctx.lengthKey(null), '');
    assert.notEqual(ctx.lengthKey(player({ identity: 'A', track: 't' })), ctx.lengthKey(player({ identity: 'B', track: 't' })));
});
