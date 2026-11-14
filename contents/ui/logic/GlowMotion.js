.pragma library

// Cursor glow motion (D-41). Pure: QML feeds the pointer, the frame time and the settings, and renders what comes back.
// The glow asks for frames only while something is still changing (needsFrames), so it costs nothing at rest.

// Frame-rate independent exponential smoothing: the same real time gives the same distance at 60 or 165 Hz.
function smooth(pos, target, dtMs, tauMs) {
    return pos + (target - pos) * (1 - Math.exp(-Math.max(0, dtMs) / Math.max(1e-6, tauMs)));
}

function isSettled(state, input, settlePx) {
    return Math.abs(input.tx - state.x) < settlePx && Math.abs(input.ty - state.y) < settlePx;
}

function targetStrength(input) {
    return input.hover ? 1 : 0;
}

// state {x, y, s}: smoothed position and fade (0..1). input {tx, ty, hover, off}: pointer target, inside the surface, and
// "Plasma animations are disabled". cfg {tauMs, fadeMs, settlePx}. Returns a new state.
function advance(state, input, dtMs, cfg) {
    const goal = targetStrength(input);
    // Fully faded out and entering again, or animations off: no flight from the old spot, no fade.
    if (input.off || (state.s <= 0 && goal > 0))
        return { "x": input.tx, "y": input.ty, "s": input.off ? goal : Math.min(goal, Math.max(0, dtMs) / cfg.fadeMs) };
    const step = Math.max(0, dtMs) / cfg.fadeMs;
    const s = goal > state.s ? Math.min(goal, state.s + step) : Math.max(goal, state.s - step);
    if (isSettled(state, input, cfg.settlePx))
        return { "x": input.tx, "y": input.ty, "s": s };
    return { "x": smooth(state.x, input.tx, dtMs, cfg.tauMs), "y": smooth(state.y, input.ty, dtMs, cfg.tauMs), "s": s };
}

// True while a frame can still change what is drawn: still fading, or the position has not reached the pointer.
function needsFrames(state, input, cfg) {
    return state.s !== targetStrength(input) || (state.s > 0 && !isSettled(state, input, cfg.settlePx))
        || (input.hover && !isSettled(state, input, cfg.settlePx));
}

// Smoothstep so the fade has soft ends; the linear value stays the state.
function eased(s) {
    const t = Math.max(0, Math.min(1, s));
    return t * t * (3 - 2 * t);
}

// Plasma's animation speed factor 0 makes Kirigami.Units durations 1.
function animationsOff(longDuration) {
    return longDuration <= 1;
}
