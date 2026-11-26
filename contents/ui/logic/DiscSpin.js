.pragma library

// The Pill's compact artwork turning like a disc while music plays (D-68). Pure functions of the held state and the
// clock; the service keeps the state, the view only draws the angle.

// A turn takes 360 / degPerSecond seconds.
const degPerSecond = 10;
// Rate requested from the shared DecorClock (D-34).
const fps = 8;
// A gap longer than this (view recreated, clock paused) is not caught up on.
const maxGapMs = 1000;

function initial() {
    return { "key": "", "angle": 0, "at": 0, "spinning": false };
}

// Only real music artwork in the Pill turns, and only where the audio bars would also be moving.
function spinWanted(i) {
    return i.pill === true && i.playing === true && i.artworkReady === true && i.kind === "music" && i.panelHidden !== true && i.reduceMotion !== true;
}

// input: { key, spinning }. A new track starts at 0; while not spinning the angle is held and resumed from.
function step(held, input, nowMs) {
    const same = held.key === input.key;
    const dt = nowMs - held.at;
    const advance = same && held.spinning && input.spinning && dt > 0 && dt <= maxGapMs ? dt : 0;
    const base = same ? held.angle : 0;
    return { "key": input.key, "angle": (base + advance / 1000 * degPerSecond) % 360, "at": nowMs, "spinning": input.spinning };
}

// What to draw for a track: the held angle, or 0 when the held state belongs to another track.
function angleFor(held, key) {
    return held.key === key ? held.angle : 0;
}
