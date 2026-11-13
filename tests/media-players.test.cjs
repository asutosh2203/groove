const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// D-39: an explicit filter and ordered sort keys, eligible -> not a bare browser -> playing -> most recently active ->
// native before browser -> richer metadata. The service records when each player last started and stopped playing and hands
// the times in; this file stays pure.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const uctx = vm.createContext({ isFinite, Number, Math });
vm.runInContext(read('Utils.js'), uctx);
const ctx = vm.createContext({ Utils: { finiteNumber: uctx.finiteNumber }, isFinite, Number, Math, String });
vm.runInContext(read('MediaPlayers.js'), ctx);
const M = ctx;
const idleCtx = vm.createContext({});
vm.runInContext(read('MediaIdle.js'), idleCtx);
const Idle = idleCtx;
const S = { playing: 2, paused: 3, stopped: 1 }; // Mpris.PlaybackStatus: Stopped 1, Playing 2, Paused 3
const j = (v) => JSON.parse(JSON.stringify(v));
const player = (o) => ({ playbackStatus: S.playing, track: '', artist: '', album: '', artUrl: '', length: 0, identity: '', desktopEntry: '', canControl: false, canPlay: false, canPause: false, startedAt: 0, stoppedAt: 0, ...o });
const idx = (candidates) => { const r = M.pick(candidates, S); return r.source === 'candidate' ? r.index : -1; };

const spotify = (o) => player({ identity: 'Spotify', track: 'Song', artist: 'Band', album: 'LP', artUrl: 'x', length: 1e8, canControl: true, canPlay: true, ...o });
const youtube = (o) => player({ identity: 'Mozilla Firefox', desktopEntry: 'firefox', track: 'Video', artist: 'Chan', length: 6e8, canControl: true, canPlay: true, ...o });

// --- who may be shown --------------------------------------------------------------------------------------------------

test('a stopped player and a missing one are never shown', () => {
    assert.equal(M.eligible(player({ playbackStatus: S.stopped, track: 'x' }), S), false);
    assert.equal(M.eligible(null, S), false);
    assert.equal(M.eligible(undefined, S), false);
    assert.equal(idx([player({ playbackStatus: S.stopped, track: 'x' })]), -1);
    assert.equal(idx([]), -1);
});

test('a paused player needs some metadata, a playing one is shown even without', () => {
    assert.equal(M.eligible(player({ playbackStatus: S.paused }), S), false);
    assert.equal(M.eligible(player({ playbackStatus: S.paused, track: 't' }), S), true);
    assert.equal(M.eligible(player({ playbackStatus: S.playing }), S), true);
});

test('nothing eligible gives none', () => {
    assert.deepEqual(j(M.pick([player({ playbackStatus: S.stopped }), player({ playbackStatus: S.paused }), null], S)), { source: 'none' });
});

// --- the sort keys, one at a time ----------------------------------------------------------------------------------------

test('a playing player comes before a paused one', () => {
    assert.equal(idx([youtube({ playbackStatus: S.paused, stoppedAt: 900 }), spotify({ startedAt: 100 })]), 1);
});

test('among players that are playing, the one that started last wins', () => {
    assert.equal(idx([spotify({ startedAt: 100 }), youtube({ startedAt: 200 })]), 1);
    assert.equal(idx([youtube({ startedAt: 200 }), spotify({ startedAt: 100 })]), 0);
});

test('among players that are not playing, the one that stopped last wins, so a just-paused player stays up', () => {
    const a = spotify({ playbackStatus: S.paused, startedAt: 100, stoppedAt: 500 });
    const b = youtube({ playbackStatus: S.paused, startedAt: 200, stoppedAt: 400 });
    assert.equal(idx([a, b]), 0);
    assert.equal(idx([b, a]), 1);
});

test('equal recency: a native player comes before a browser, even a richer one', () => {
    const native = player({ identity: 'Spotify', track: 'Song', startedAt: 100 });
    const browser = youtube({ startedAt: 100 }); // far richer metadata
    assert.equal(idx([browser, native]), 1);
    assert.equal(idx([native, browser]), 0);
});

test('equal in everything but metadata: the richer one wins', () => {
    const thin = player({ identity: 'Spotify', track: 'Song', startedAt: 100 });
    const rich = spotify({ startedAt: 100 });
    assert.equal(idx([thin, rich]), 1);
    assert.equal(idx([rich, thin]), 0);
});

test('equal in every key: the first in the model order wins', () => {
    assert.equal(idx([spotify({ startedAt: 100 }), spotify({ startedAt: 100 })]), 0);
});

test('a browser with no metadata comes last (the old penalty), even when it started playing last', () => {
    const bare = player({ identity: 'Google Chrome', startedAt: 900 });
    assert.equal(M.hasMetadata(bare), false);
    assert.equal(idx([bare, spotify({ startedAt: 100 })]), 1);
    assert.equal(idx([bare, spotify({ playbackStatus: S.paused, stoppedAt: 50 })]), 1);
    assert.equal(idx([bare]), 0); // but it is shown when nothing else is
    assert.equal(M.isBrowserish(player({ desktopEntry: 'vivaldi-stable' })), true);
    assert.equal(M.isBrowserish(player({ identity: 'Spotify' })), false);
});

// --- the scenarios ---------------------------------------------------------------------------------------------------------

test('Spotify is playing, then a YouTube video starts: YouTube wins', () => {
    const sp = spotify({ startedAt: 1000 });
    const yt = youtube({ startedAt: 5000 });
    assert.equal(idx([sp, yt]), 1);
});

test('resuming the older player makes it win again', () => {
    let sp = M.noteStatus(null, true, 1000); // Spotify discovered playing at t=1000
    let yt = M.noteStatus(null, false, 1000);
    yt = M.noteStatus(yt, true, 5000); // YouTube starts
    const view = () => [spotify({ startedAt: sp.startedAt, stoppedAt: sp.stoppedAt }), youtube({ startedAt: yt.startedAt, stoppedAt: yt.stoppedAt })];
    assert.equal(idx(view()), 1); // YouTube, the latest start
    sp = M.noteStatus(sp, false, 6000); // Spotify paused
    sp = M.noteStatus(sp, true, 9000); // and resumed: it started most recently now
    assert.equal(idx(view()), 0);
});

test('pausing both keeps the one paused last on screen', () => {
    let sp = M.noteStatus(M.noteStatus(null, true, 1000), false, 7000); // Spotify paused at 7000
    let yt = M.noteStatus(M.noteStatus(M.noteStatus(null, false, 1000), true, 5000), false, 8000); // YouTube paused at 8000
    const paused = (r, make) => make({ playbackStatus: S.paused, startedAt: r.startedAt, stoppedAt: r.stoppedAt });
    assert.equal(idx([paused(sp, spotify), paused(yt, youtube)]), 1); // YouTube was paused last
    sp = M.noteStatus(M.noteStatus(sp, true, 8500), false, 9000); // Spotify played and paused again, later than YouTube
    assert.equal(idx([paused(sp, spotify), paused(yt, youtube)]), 0);
});

test('startup with both already playing: discovery time is the start; a tie goes to the native player', () => {
    const sp = M.noteStatus(null, true, 3000);
    const yt = M.noteStatus(null, true, 3000);
    assert.deepEqual(j(sp), { playing: true, startedAt: 3000, stoppedAt: 0 });
    assert.equal(idx([youtube({ startedAt: yt.startedAt }), spotify({ startedAt: sp.startedAt })]), 1); // same time: native first
    // discovered one after the other: the later discovery wins
    assert.equal(idx([spotify({ startedAt: 3000 }), youtube({ startedAt: 3050 })]), 1);
});

test('a browser and a native player that started together: the native player wins', () => {
    assert.equal(idx([youtube({ startedAt: 200 }), spotify({ startedAt: 200 })]), 1);
});

// --- recording the times --------------------------------------------------------------------------------------------------

test('noteStatus stamps a start into Playing, a stop out of it, and ignores a repeat', () => {
    assert.deepEqual(j(M.noteStatus(null, false, 100)), { playing: false, startedAt: 0, stoppedAt: 0 }); // never seen playing
    const playing = M.noteStatus(null, true, 100);
    assert.equal(M.noteStatus(playing, true, 999), playing); // still playing: unchanged
    const stopped = M.noteStatus(playing, false, 200);
    assert.deepEqual(j(stopped), { playing: false, startedAt: 100, stoppedAt: 200 });
    assert.equal(M.noteStatus(stopped, false, 999), stopped);
    assert.deepEqual(j(M.noteStatus(stopped, true, 300)), { playing: true, startedAt: 300, stoppedAt: 200 });
});

// --- what differs from the points-based ranking this replaces ---------------------------------------------------------------

test('against the old scoring (all times equal) the picks agree except in two intended ways', () => {
    // The old score, as it was: status 1000 / 500 / 100, metadata points, controls, and -400 for a browser without metadata.
    const oldScore = (p) => {
        if (p.playbackStatus === S.stopped) return -1;
        if (p.playbackStatus !== S.playing && !M.hasMetadata(p)) return -1;
        let s = p.playbackStatus === S.playing ? 1000 : p.playbackStatus === S.paused ? 500 : 100;
        s += M.richness(p);
        if (M.isBrowserish(p) && !M.hasMetadata(p)) s -= 400;
        return s;
    };
    const oldPick = (ps) => { let best = -1, bs = -1; ps.forEach((p, i) => { const s = oldScore(p); if (s > bs) { best = i; bs = s; } }); return bs >= 0 ? best : -1; };
    let seed = 21;
    const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
    const choose = (a) => a[Math.floor(rnd() * a.length)];
    const meta = { none: {}, track: { track: 'T' }, rich: { track: 'T', artist: 'A', album: 'B', artUrl: 'u', length: 1e8 } };
    const make = (i) => { const browser = choose([true, false]); const ctl = choose([true, false]); return player({ playbackStatus: choose([S.playing, S.paused, S.stopped]), identity: (browser ? 'Mozilla Firefox' : 'Spotify') + i, canControl: ctl, canPlay: ctl, ...meta[choose(['none', 'track', 'rich'])] }); };
    const bare = (p) => M.isBrowserish(p) && !M.hasMetadata(p);
    let identical = 0, nativeOverRicherBrowser = 0, bareBrowserDemoted = 0;
    const unexplained = [];
    for (let k = 0; k < 20000; ++k) {
        const ps = Array.from({ length: 1 + Math.floor(rnd() * 3) }, (_, i) => make(i));
        const a = oldPick(ps), b = idx(ps);
        if (a === b) { identical++; continue; }
        const pa = ps[a], pb = ps[b];
        const samePlaying = pa && pb && (pa.playbackStatus === S.playing) === (pb.playbackStatus === S.playing);
        if (pa && pb && samePlaying && M.isBrowserish(pa) && !M.isBrowserish(pb)) nativeOverRicherBrowser++;
        else if (pa && pb && !samePlaying && bare(pa)) bareBrowserDemoted++;
        else unexplained.push(JSON.stringify(ps.map((p) => p.identity + ':' + p.playbackStatus)));
    }
    assert.deepEqual(unexplained, []);
    assert.ok(identical > 17000, 'identical picks: ' + identical);
    assert.ok(nativeOverRicherBrowser > 0 && bareBrowserDemoted > 0, 'both intended differences occur');
});

// --- text, times and the length key (unchanged) -------------------------------------------------------------------------------

test('text collapses whitespace and tolerates nullish', () => {
    assert.equal(M.text('  a   b\n c '), 'a b c');
    assert.equal(M.text(null), '');
    assert.equal(M.text(undefined), '');
});

test('times read as m:ss from microseconds and survive junk', () => {
    assert.equal(M.formatTime(0), '0:00');
    assert.equal(M.formatTime(59e6), '0:59');
    assert.equal(M.formatTime(61e6), '1:01');
    assert.equal(M.formatTime(3600e6), '60:00');
    assert.equal(M.formatTime(-1), '0:00');
    assert.equal(M.formatTime('junk'), '0:00');
    assert.equal(M.formatProgress(61e6, 270680000), '1:01 / 4:30');
});

test('lengthKey ties a length to one track on one player', () => {
    assert.equal(M.lengthKey(spotify()), 'Spotify|Song|Band');
    assert.equal(M.lengthKey(null), '');
    assert.notEqual(M.lengthKey(player({ identity: 'A', track: 't' })), M.lengthKey(player({ identity: 'B', track: 't' })));
});

// --- D-35: a ghost tab must not hold the media pill up -------------------------------------------------------------------

test('only a Playing player that is not a demoted browser counts as playing', () => {
    assert.equal(M.countsAsPlaying(spotify(), S), true);
    assert.equal(M.countsAsPlaying(youtube(), S), true); // a browser with metadata counts
    assert.equal(M.countsAsPlaying(player({ identity: 'Google Chrome' }), S), false); // a bare browser tab: a ghost
    assert.equal(M.countsAsPlaying(spotify({ playbackStatus: S.paused }), S), false);
    assert.equal(M.countsAsPlaying(null, S), false);
    assert.equal(M.isDemoted(player({ desktopEntry: 'firefox' })), true);
    assert.equal(M.isDemoted(spotify()), false);
});

// Runs the service's idle rule for the chosen player: the event it would send, then the grace timeout.
function idleAfterGrace(candidates) {
    const r = M.pick(candidates, S);
    const chosen = r.source === 'candidate' ? candidates[r.index] : null;
    const event = !chosen ? 'gone' : M.countsAsPlaying(chosen, S) ? 'playing' : 'notPlaying';
    let state = JSON.parse(JSON.stringify(Idle.reduce({ expired: false }, event)));
    const shownAtOnce = Idle.shown(!!chosen, event === 'playing', state.expired);
    if (state.scheduleMs !== null) state = JSON.parse(JSON.stringify(Idle.reduce(state, 'timeout')));
    return { shownAtOnce, shownAfterGrace: Idle.shown(!!chosen, event === 'playing', state.expired) };
}

test('a ghost tab that only claims to play gives way to the idle face after the grace period', () => {
    const ghost = player({ identity: 'Google Chrome', startedAt: 900 });
    assert.equal(idx([ghost]), 0); // it is still the player shown at first...
    assert.deepEqual(idleAfterGrace([ghost]), { shownAtOnce: true, shownAfterGrace: false }); // ...but 30 s later the island is idle
});

test('a ghost tab does not stop a paused real player from idling either', () => {
    const ghost = player({ identity: 'Google Chrome', startedAt: 900 });
    const paused = spotify({ playbackStatus: S.paused, stoppedAt: 100 });
    assert.equal(idx([ghost, paused]), 1); // the real one is chosen (the ghost is demoted)
    assert.deepEqual(idleAfterGrace([ghost, paused]), { shownAtOnce: true, shownAfterGrace: false });
});

test('a real playing player is never idled, and a ghost that gets metadata starts counting', () => {
    assert.deepEqual(idleAfterGrace([spotify({ startedAt: 1 })]), { shownAtOnce: true, shownAfterGrace: true });
    const wakes = player({ identity: 'Google Chrome', track: 'Now a real title', startedAt: 900 });
    assert.deepEqual(idleAfterGrace([wakes]), { shownAtOnce: true, shownAfterGrace: true });
});
