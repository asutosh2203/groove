.pragma library

// Do Not Disturb during focus (D-64). Plasma's own toggle writes `notificationsInhibitedUntil`; Kove sets it to the focus
// phase's end so it expires by itself, even if Kove dies. Kove clears only what it set: a DND the user already had (until
// later, or indefinitely, which Plasma stores as a far-future date) is left alone and never cleared.
//
// A state is { ours: false } or { ours: true, until } (the ms Kove wrote). `current` is the value Plasma holds now, in ms,
// or null when DND is off. Each step returns { state, effects } where effects run in order: { op: "set", until } or
// { op: "clear" } on Plasma's setting, then { op: "alert" } (the phase-end notification).

const TOLERANCE_MS = 1500;

function idle() {
    return { "ours": false };
}

function active(current, now) {
    return current !== null && current !== undefined && current > now;
}

// A focus phase starts or resumes and will end at `endsAt`.
function engage(state, current, endsAt, now) {
    if (active(current, now) && current >= endsAt + TOLERANCE_MS && !state.ours)
        return { "state": idle(), "effects": [] };
    return { "state": { "ours": true, "until": endsAt }, "effects": [{ "op": "set", "until": endsAt }] };
}

// Pause, skip, reset, a deleted placement or the phase ending. Clears only if Kove set it and Plasma still holds that
// value (the user did not change it meanwhile); `alert` adds the phase-end notification AFTER the clear.
function release(state, current, now, alert) {
    const effects = [];
    const same = active(current, now) && state.ours && Math.abs(current - state.until) <= TOLERANCE_MS;
    if (same)
        effects.push({ "op": "clear" });
    if (alert)
        effects.push({ "op": "alert" });
    return { "state": idle(), "effects": effects };
}
