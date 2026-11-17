.pragma library

// The deck (D-51): which pages exist, which one opens, how big the window must be. Pure functions of plain data.
// A page is { id, type }; type is "live", "small", "wide", "tall" or "control". Cell units follow D-48.

const cells = { "small": { w: 2, h: 1 }, "wide": { w: 4, h: 1 }, "tall": { w: 2, h: 2 } };

// [Live] -> [dev pages] -> [Control Center, always last]. Live is in the cycle only while something runs.
function buildCycle(liveActive, dummyPages) {
    const pages = [];
    if (liveActive)
        pages.push({ "id": "live", "type": "live" });
    if (dummyPages) {
        pages.push({ "id": "dummy-small", "type": "small" });
        pages.push({ "id": "dummy-wide", "type": "wide" });
        pages.push({ "id": "dummy-tall", "type": "tall" });
    }
    pages.push({ "id": "control", "type": "control" });
    return pages;
}

function indexOf(cycle, id) {
    for (let i = 0; i < cycle.length; ++i) {
        if (cycle[i].id === id)
            return i;
    }
    return -1;
}

// The page type Live is drawn as: one card is Small, two or more Wide (the last odd card sits in the left slot).
function liveType(cardCount) {
    return cardCount >= 2 ? "wide" : "small";
}

// geom: { cellW, cellH, inset, controlW, controlH, controlEditW, controlEditH }. Cell pages reserve the bottom inset
// for the indicator and the Live chips whether or not they show; the Control Center keeps its own layout.
function pageSize(type, geom) {
    if (type === "control")
        return { "w": geom.controlW, "h": geom.controlH };
    const c = cells[type] || cells.small;
    return { "w": c.w * geom.cellW, "h": c.h * geom.cellH + geom.inset };
}

// The window is sized once, before the deck shows: the largest width and the largest height in the cycle. Live always
// counts as Wide (a second activity can arrive while open) and the Control Center as its edit size.
function windowSize(cycle, geom) {
    let w = 0;
    let h = 0;
    for (const page of cycle) {
        const size = page.type === "live" ? pageSize("wide", geom) : page.type === "control" ? { "w": geom.controlEditW, "h": geom.controlEditH } : pageSize(page.type, geom);
        w = Math.max(w, size.w);
        h = Math.max(h, size.h);
    }
    return { "w": w, "h": h };
}

// Which page a capsule click opens: "double" is the Control Center; "click" is Live when it exists, else the page last
// used this session, else the first page.
function entryPage(cycle, lastUsedId, intent) {
    if (intent === "double")
        return "control";
    if (indexOf(cycle, "live") >= 0)
        return "live";
    if (indexOf(cycle, lastUsedId) >= 0)
        return lastUsedId;
    return cycle[0].id;
}

// null for a one-page deck. Pill = Live, dots = presets, gear = Control Center; the current page is flagged.
function indicator(cycle, currentId) {
    if (cycle.length < 2)
        return null;
    return cycle.map(page => ({
                "id": page.id,
                "kind": page.type === "live" ? "pill" : page.type === "control" ? "gear" : "dot",
                "current": page.id === currentId
            }));
}

// The cycle changed while the deck is open. A page that still exists stays put (Live appearing only adds the pill).
// If the viewed page vanished (Live emptied), move to the next page that is left, else the Control Center.
function reconcile(oldCycle, newCycle, currentId) {
    if (indexOf(newCycle, currentId) >= 0)
        return currentId;
    for (let i = indexOf(oldCycle, currentId) + 1; i < oldCycle.length; ++i) {
        if (indexOf(newCycle, oldCycle[i].id) >= 0)
            return oldCycle[i].id;
    }
    return "control";
}
