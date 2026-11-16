.pragma library

// Inline reply shelf (D-43). Phases: closed, opening, open, sending, error (the draft is kept for a retry).

const dwellMs = 200;

function initial() {
    return { "phase": "closed", "error": "" };
}

function isOpen(state) {
    return state.phase !== "closed";
}

// events: open | opened | close | send | sent | failed(message) | edit
function reduce(state, type, message) {
    switch (type) {
    case "open":
        return state.phase === "closed" ? { "phase": "opening", "error": "" } : state;
    case "opened":
        return state.phase === "opening" ? { "phase": "open", "error": "" } : state;
    case "close":
        return state.phase === "sending" ? state : initial();
    case "send":
        return state.phase === "opening" || state.phase === "open" || state.phase === "error" ? { "phase": "sending", "error": "" } : state;
    case "sent":
        return state.phase === "sending" ? initial() : state;
    case "failed":
        return state.phase === "sending" ? { "phase": "error", "error": message || "" } : state;
    case "edit":
        return state.phase === "error" ? { "phase": "open", "error": "" } : state;
    }
    return state;
}

function canSend(draft) {
    return typeof draft === "string" && draft.trim().length > 0;
}

// D-43: the popup never ends under a focused or non-empty field.
function holdsLifetime(state, fieldFocused, draft) {
    if (!isOpen(state))
        return false;
    return state.phase === "sending" || fieldFocused === true || (typeof draft === "string" && draft.length > 0);
}

function escapeAction(state) {
    return isOpen(state) && state.phase !== "sending" ? "closeShelf" : "closePopup";
}

function leaveAction(state, draft, fieldFocused) {
    if (!isOpen(state) || state.phase === "sending")
        return "none";
    return fieldFocused === true || (typeof draft === "string" && draft.length > 0) ? "none" : "close";
}

function placeholder(modelText, fallbackText) {
    const text = typeof modelText === "string" ? modelText.trim() : "";
    return text.length > 0 ? text : fallbackText;
}

// D-26: apps send plain names like "mail-send".
function symbolicName(name) {
    if (typeof name !== "string" || name.trim().length === 0)
        return "";
    const clean = name.trim();
    return clean.endsWith("-symbolic") ? clean : clean + "-symbolic";
}

// The dwell fires once per hover session: after the shelf closes it stays closed until the pointer leaves and returns.
function shouldDwell(state, hovering, eligible, spent) {
    return hovering === true && eligible === true && spent !== true && state.phase === "closed";
}
