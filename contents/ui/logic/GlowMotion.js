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

// Bloom (D-41, D-43): spring out, hold, dissolve. Springs run in seconds (K in 1/s^2, D in 1/s).
const bloomCfg = {
    "radiusBoost": 1.6, "intensity": 0.06, "springK": 180, "springD": 14, "springMaxMs": 700, "holdMs": 200,
    "dissolveRadius": 1.6, "dissolveK": 40, "dissolveD": 12.65, "dissolveMaxMs": 1500, "stepMs": 4, "doneIntensity": 0.0005
};

// r is a multiple of the base radius.
function bloomStart(startIntensity) {
    return { "phase": "spring", "r": 1, "vr": 0, "i": startIntensity, "vi": 0, "t": 0 };
}

function bloomActive(state) {
    return state !== null && state !== undefined && state.phase !== "done";
}

function bloomIdle() {
    return { "phase": "done", "r": 1, "vr": 0, "i": 0, "vi": 0, "t": 0 };
}

function springTo(x, v, target, k, d, h) {
    const nv = v + (-k * (x - target) - d * v) * h;
    return [x + nv * h, nv];
}

function bloomAdvance(state, dtMs) {
    if (!bloomActive(state))
        return state;
    let s = { "phase": state.phase, "r": state.r, "vr": state.vr, "i": state.i, "vi": state.vi, "t": state.t };
    let left = Math.min(Math.max(0, dtMs), 50);
    while (left > 0 && s.phase !== "done") {
        const stepMs = Math.min(bloomCfg.stepMs, left);
        const h = stepMs / 1000;
        left -= stepMs;
        s.t += stepMs;
        if (s.phase === "spring") {
            const tr = bloomCfg.radiusBoost;
            const rr = springTo(s.r, s.vr, tr, bloomCfg.springK, bloomCfg.springD, h);
            const ii = springTo(s.i, s.vi, bloomCfg.intensity, bloomCfg.springK, bloomCfg.springD, h);
            s.r = rr[0]; s.vr = rr[1]; s.i = ii[0]; s.vi = ii[1];
            const settled = Math.abs(s.r - tr) < 0.01 && Math.abs(s.vr) < 0.05;
            if (settled || s.t >= bloomCfg.springMaxMs) {
                s.phase = "hold";
                s.t = 0;
            }
        } else if (s.phase === "hold") {
            if (s.t >= bloomCfg.holdMs) {
                s.phase = "dissolve";
                s.t = 0;
            }
        } else {
            const tr = bloomCfg.radiusBoost * bloomCfg.dissolveRadius;
            const rr = springTo(s.r, s.vr, tr, bloomCfg.dissolveK, bloomCfg.dissolveD, h);
            const ii = springTo(s.i, s.vi, 0, bloomCfg.dissolveK, bloomCfg.dissolveD, h);
            s.r = rr[0]; s.vr = rr[1]; s.i = Math.max(0, ii[0]); s.vi = ii[1];
            if (s.i <= bloomCfg.doneIntensity || s.t >= bloomCfg.dissolveMaxMs)
                s.phase = "done";
        }
    }
    return s;
}
