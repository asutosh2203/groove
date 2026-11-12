.pragma library
.import "Utils.js" as Utils

// Which MPRIS player the island shows, and how its times read. A "player-like" is anything with the fields below
// (a delegate of the player model, or the model's current player): playbackStatus, track, artist, album, artUrl,
// length, identity, desktopEntry, canControl, canPlay, canPause. `status` is { playing, paused, stopped }: the
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

// Higher wins; -1 means "not worth showing" (stopped, or idle without metadata).
function score(player, status) {
    if (!player)
        return -1;

    const playback = player.playbackStatus;
    const metadata = hasMetadata(player);
    if (playback === status.stopped)
        return -1;

    if (playback !== status.playing && !metadata)
        return -1;

    let points = 0;
    if (playback === status.playing)
        points += 1000;
    else if (playback === status.paused)
        points += 500;
    else
        points += 100;

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
    if (isBrowserish(player) && !metadata)
        points -= 400;

    return points;
}

// The best of the instantiated candidates and the model's own current player (the fallback). The first candidate wins
// a tie; the fallback only when it scores strictly higher. Returns { source: "candidate", index } | { source:
// "fallback" } | { source: "none" }.
function pick(candidates, fallback, status) {
    let best = { "source": "none" };
    let bestScore = -1;
    for (let i = 0; i < candidates.length; ++i) {
        const points = score(candidates[i], status);
        if (points > bestScore) {
            best = { "source": "candidate", "index": i };
            bestScore = points;
        }
    }
    if (score(fallback, status) > bestScore) {
        best = { "source": "fallback" };
        bestScore = score(fallback, status);
    }
    return bestScore >= 0 ? best : { "source": "none" };
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
