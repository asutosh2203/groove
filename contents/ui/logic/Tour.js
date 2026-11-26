.pragma library

// The welcome tour (D-69): which version of it is current, when it shows and how its stepper moves. Pure functions.
// The page's words live in Strings.qml; the ids here are only their keys.

// Bump when the tour gains something a returning user should see; Done and Skip store this number.
const VERSION = 1;
const STEPS = ["island", "live", "deck", "customize", "gestures"];
// Theme symbolic names to try per step, in order (D-26); the last one is a Breeze name, so nothing renders blank.
const ICONS = {
    "island": ["weather-few-clouds-symbolic", "clock-symbolic", "window-symbolic"],
    "live": ["notifications-symbolic", "media-playback-start-symbolic"],
    "deck": ["view-grid-symbolic", "window-symbolic"],
    "customize": ["document-edit-symbolic", "edit-symbolic"],
    "gestures": ["input-mouse-symbolic", "configure-symbolic"]
};

function version() {
    return VERSION;
}

function steps() {
    return STEPS.slice();
}

function count() {
    return STEPS.length;
}

// The tour shows while the stored number is below the current version. A missing or odd value counts as 0.
function shouldShow(input) {
    const stored = Number.isInteger(input.tourVersion) ? input.tourVersion : 0;
    const current = Number.isInteger(input.version) ? input.version : VERSION;
    return stored < current;
}

function clamp(step) {
    return Math.max(0, Math.min(STEPS.length - 1, Number.isInteger(step) ? step : 0));
}

function next(step) {
    return clamp(clamp(step) + 1);
}

function back(step) {
    return clamp(clamp(step) - 1);
}

// What the footer shows for a step: the counter's two numbers, which buttons exist and what the primary one does.
function view(step) {
    const s = clamp(step);
    return {
        "id": STEPS[s],
        "icons": ICONS[STEPS[s]].slice(),
        "n": s + 1,
        "total": STEPS.length,
        "canBack": s > 0,
        "primary": s === STEPS.length - 1 ? "done" : "next"
    };
}
