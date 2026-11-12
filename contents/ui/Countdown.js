.pragma library

// A countdown that can be paused and resumed with the time it had left (not restarted).
// State is a plain object; every function takes the current time in ms so it stays testable.
function start(now, durationMs) {
    const duration = Math.max(0, Number(durationMs) || 0);
    return { paused: false, endsAt: now + duration, remaining: duration };
}

function remaining(state, now) {
    if (!state)
        return 0;
    return state.paused ? state.remaining : Math.max(0, state.endsAt - now);
}

function pause(state, now) {
    if (!state || state.paused)
        return state;
    return { paused: true, endsAt: state.endsAt, remaining: remaining(state, now) };
}

function resume(state, now) {
    if (!state || !state.paused)
        return state;
    return { paused: false, endsAt: now + state.remaining, remaining: state.remaining };
}
