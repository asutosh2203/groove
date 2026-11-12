.pragma library

// Decorative loops as pure functions of time (ms). One shared low-rate clock supplies `t`, so an icon or a
// set of bars is redrawn at the clock's rate instead of at the display rate (see DecorClock.qml, D-34).

// QML's Easing.InOutSine for a progress p in 0..1.
function inOutSine(p) {
    const x = Math.max(0, Math.min(1, p));
    return 0.5 - 0.5 * Math.cos(Math.PI * x);
}

function lerp(a, b, p) {
    return a + (b - a) * p;
}

// A looped "rest, go to `to` over d1, come back to `from` over d2" cycle, optionally starting after `delay`.
// Returns the value at time t. This is the shape of the AudioBars and the moon/cloud motions.
function cycle(t, delay, d1, d2, from, to) {
    const length = delay + d1 + d2;
    const u = ((t % length) + length) % length;
    if (u < delay)
        return from;
    if (u < delay + d1)
        return lerp(from, to, inOutSine((u - delay) / d1));
    return lerp(to, from, inOutSine((u - delay - d1) / d2));
}

// 0..1 position inside a repeating period.
function phase(t, periodMs) {
    return (((t % periodMs) + periodMs) % periodMs) / periodMs;
}

// Same as cycle() but bouncing between two values with no rest and equal halves (clouds sway, moon).
function sway(t, halfMs, a, b) {
    return cycle(t, 0, halfMs, halfMs, a, b);
}

// The thunderstorm flash: full brightness, a pause, then a quick stutter back to full.
const boltSteps = [[2600, 1], [60, 0.15], [70, 1], [60, 0.35], [140, 1]]; // [duration ms, value reached]

function bolt(t) {
    let total = 0;
    for (const s of boltSteps)
        total += s[0];
    let u = ((t % total) + total) % total;
    let previous = 1;
    for (const s of boltSteps) {
        if (u < s[0])
            return s[0] === 2600 ? 1 : lerp(previous, s[1], u / s[0]);
        u -= s[0];
        previous = s[1];
    }
    return 1;
}
