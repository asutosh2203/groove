.pragma library

// Which job row is open in the Live list (D-53): at most one, by job id, "" for none. Pure functions of the open id and
// the ids now in the list; the state itself is per session and resets when the deck closes.

// A click on a row: opens it, swaps to it from another, or closes it when it was the open one.
function toggle(openId, id) {
    return openId === id ? "" : id;
}

// The open row's job finished or left: nothing is open.
function clamp(openId, ids) {
    return openId !== "" && ids.indexOf(openId) >= 0 ? openId : "";
}
