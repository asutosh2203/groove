.pragma library

// Which job row is open in the Live list (D-51): at most one, by job id, "" for none. Pure functions of the open id and
// the ids now in the list; the state itself is per session and resets when the deck closes.

// A click on a row: opens it, swaps to it from another, or closes it when it was the open one.
function toggle(openId, id) {
    return openId === id ? "" : id;
}

// The open row's job finished or left: nothing is open.
function clamp(openId, ids) {
    return openId !== "" && ids.indexOf(openId) >= 0 ? openId : "";
}

// How far to scroll so the open row is fully in view: returns the new contentY. Rows are `step` apart (row height plus
// gap) except the open one, which is `openHeight` tall. contentY stays as it is when the row already fits.
function scrollTarget(ids, openId, contentY, viewHeight, rowHeight, openHeight, gap) {
    const index = ids.indexOf(openId);
    if (index < 0)
        return contentY;
    const top = index * (rowHeight + gap);
    const bottom = top + openHeight;
    if (top < contentY)
        return top;
    if (bottom > contentY + viewHeight)
        return Math.max(0, bottom - viewHeight);
    return contentY;
}
