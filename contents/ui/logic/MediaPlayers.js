.pragma library
.import "Utils.js" as Utils

// Which MPRIS player the island shows (D-39), and how its times read. A "player-like" is anything with the fields below:
// playbackStatus, track, artist, album, artUrl, length, identity, desktopEntry, canControl, canPlay, canPause, and the
// times startedAt / stoppedAt that the service records. `status` is { playing, paused, stopped }: the
// numeric values of Mpris.PlaybackStatus, handed in so this file needs no Plasma import.

function text(value) {
    return String(value || "").replace(/\s+/g, " ").trim();
}

function hasMetadata(player) {
    if (!player)
        return false;

    return text(player.track).length > 0 || text(player.artist).length > 0 || text(player.album).length > 0 || text(player.artUrl).length > 0 || Utils.finiteNumber(player.length, 0) > 0;
}

function isBrowserish(player) {
    if (!player)
        return false;

    const name = (text(player.identity) + " " + text(player.desktopEntry)).toLowerCase();
    return name.indexOf("vivaldi") !== -1 || name.indexOf("chromium") !== -1 || name.indexOf("chrome") !== -1 || name.indexOf("firefox") !== -1 || name.indexOf("browser") !== -1;
}

// Whether a player may be shown at all. Stopped players never are, and a player that is not playing needs some metadata
// to be worth showing (an idle player with nothing to say is not).
function eligible(player, status) {
    if (!player)
        return false;
    if (player.playbackStatus === status.stopped)
        return false;
    return player.playbackStatus === status.playing || hasMetadata(player);
}

// A browser with no metadata: usually an idle tab or a ghost (D-39 ranks it last).
function isDemoted(player) {
    return isBrowserish(player) && !hasMetadata(player);
}

// Whether the player really counts as playing, which is what the 30 s idle rule (D-35) asks: it is Playing, and it is not
// a demoted browser tab. A ghost tab that claims to be playing therefore never keeps the media pill up.
function countsAsPlaying(player, status) {
    return !!player && player.playbackStatus === status.playing && !isDemoted(player);
}

// How much the player has to show: a number used only as the last tie-break between otherwise equal players.
function richness(player) {
    let points = 0;
    if (text(player.track).length > 0)
        points += 80;
    if (text(player.artist).length > 0)
        points += 45;
    if (text(player.album).length > 0)
        points += 20;
    if (text(player.artUrl).length > 0)
        points += 20;
    if (Utils.finiteNumber(player.length, 0) > 0)
        points += 25;
    if (player.canControl)
        points += 10;
    if (player.canPlay || player.canPause)
        points += 10;
    return points;
}

// The player's recency: when it last started playing while it plays, when it last stopped once it does not
// (`startedAt` / `stoppedAt`, ms, 0 when never seen playing).
function activeAt(player, status) {
    const t = player.playbackStatus === status.playing ? player.startedAt : player.stoppedAt;
    return Utils.finiteNumber(t, 0);
}

// Orders two eligible players, negative when `a` comes first (D-39). The keys, in order:
//   1. a browser with no metadata comes last (usually an idle tab; the old -400 penalty);
//   2. a playing player before one that is not;
//   3. the most recently active first: the one that started playing last, or among players that are not playing the
//      one that stopped last, so a just-paused player stays up;
//   4. a native player before a browser;
//   5. the richer metadata first.
// Anything still equal keeps the model's order (the caller picks the first).
function compare(a, b, status) {
    const bareA = isDemoted(a);
    const bareB = isDemoted(b);
    if (bareA !== bareB)
        return bareA ? 1 : -1;
    const playingA = a.playbackStatus === status.playing;
    const playingB = b.playbackStatus === status.playing;
    if (playingA !== playingB)
        return playingA ? -1 : 1;
    const recentA = activeAt(a, status);
    const recentB = activeAt(b, status);
    if (recentA !== recentB)
        return recentB - recentA;
    const browserA = isBrowserish(a);
    const browserB = isBrowserish(b);
    if (browserA !== browserB)
        return browserA ? 1 : -1;
    return richness(b) - richness(a);
}

// The player to show among the candidates: the first of the best by `compare`, among the eligible ones. Returns
// { source: "candidate", index } or { source: "none" }.
function pick(candidates, status) {
    let best = -1;
    for (let i = 0; i < candidates.length; ++i) {
        if (!eligible(candidates[i], status))
            continue;
        if (best < 0 || compare(candidates[i], candidates[best], status) < 0)
            best = i;
    }
    return best < 0 ? { "source": "none" } : { "source": "candidate", "index": best };
}

// A player's activity record after its playback status was seen: { playing, startedAt, stoppedAt }. A player first
// seen already playing starts at the discovery time; one first seen not playing has never been seen playing (0). A change
// into Playing stamps startedAt, a change out of it stamps stoppedAt; seeing the same state again changes nothing.
function noteStatus(record, playing, nowMs) {
    if (!record)
        return { "playing": playing, "startedAt": playing ? nowMs : 0, "stoppedAt": 0 };
    if (playing && !record.playing)
        return { "playing": true, "startedAt": nowMs, "stoppedAt": record.stoppedAt };
    if (!playing && record.playing)
        return { "playing": false, "startedAt": record.startedAt, "stoppedAt": nowMs };
    return record;
}

// Identifies one track on one player, so a length held across metadata updates never leaks to another (MediaLength.js).
function lengthKey(player) {
    return player ? text(player.identity) + "|" + text(player.track) + "|" + text(player.artist) : "";
}

// MPRIS times are in microseconds.
function formatTime(value) {
    const seconds = Math.max(0, Math.floor(Utils.finiteNumber(value, 0) / 1000000));
    const minutes = Math.floor(seconds / 60);
    const remainder = seconds % 60;
    return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
}

function formatProgress(position, length) {
    return formatTime(position) + " / " + formatTime(length);
}
