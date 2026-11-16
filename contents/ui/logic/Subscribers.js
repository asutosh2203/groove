.pragma library

// Ref-count of the views that currently need a service's data. A service works only while
// it has subscribers, plus a grace period after the last one leaves (a view that flickers
// away and back must not restart polling). State is a plain object; time is passed in.
const GRACE_MS = 30000;

function create() {
    return { count: 0, graceUntil: 0 };
}

function add(state) {
    return { count: state.count + 1, graceUntil: 0 };
}

function remove(state, now) {
    const count = Math.max(0, state.count - 1);
    return { count: count, graceUntil: count === 0 ? now + GRACE_MS : 0 };
}

function isActive(state, now) {
    return state.count > 0 || now < state.graceUntil;
}

// Remaining grace in ms, 0 when subscribers exist or the grace is over.
function graceLeft(state, now) {
    return state.count > 0 ? 0 : Math.max(0, state.graceUntil - now);
}
