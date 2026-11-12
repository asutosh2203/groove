.pragma library

// When does a media player stop owning the island (D-35)? While something plays it always does. A player that
// exists but has not been playing for `graceMs` hands the island back to the idle face (clock and weather);
// anything that starts playing takes it back at once. QML only feeds events in and runs the timer.
const graceMs = 30000;

// state: { expired }. event: "playing" | "notPlaying" | "timeout" | "gone".
// Returns { expired, scheduleMs }: scheduleMs is the timer to (re)start, or null to cancel it.
function reduce(state, event) {
    switch (event) {
    case "playing":
        return { expired: false, scheduleMs: null };
    case "notPlaying":
        // Paused, stopped, or a player that appeared idle: show it for the grace period first.
        return { expired: false, scheduleMs: graceMs };
    case "timeout":
        return { expired: true, scheduleMs: null };
    case "gone":
        return { expired: false, scheduleMs: null };
    default:
        return { expired: !!(state && state.expired), scheduleMs: null };
    }
}

function shown(hasPlayer, playing, expired) {
    return hasPlayer === true && (playing === true || expired !== true);
}
