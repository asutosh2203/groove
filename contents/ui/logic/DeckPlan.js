.pragma library

// The deck (D-51): which pages exist, which one opens, how big the window must be. Pure functions of plain data.
// A page is { id, type }; type is "live", "small", "wide", "tall" or "control". Cell units follow D-48.

const cells = { "small": { w: 2, h: 1 }, "wide": { w: 4, h: 1 }, "tall": { w: 2, h: 2 } };

// At most three presets, so the worst case is five rail glyphs (Live + 3 + Control Center), which fit the Small page.
const maxPresets = 3;

// The dev flag's stand-ins for presets: one of each page type.
function dummyPresets() {
    return [{ "id": "dummy-small", "type": "small" }, { "id": "dummy-wide", "type": "wide" }, { "id": "dummy-tall", "type": "tall" }];
}

// [Live] -> [presets, at most three] -> [Control Center, always last]. Live is in the cycle only while something runs.
function buildCycle(liveActive, presets) {
    const pages = [];
    if (liveActive)
        pages.push({ "id": "live", "type": "live" });
    for (const preset of presets.slice(0, maxPresets))
        pages.push(preset);
    pages.push({ "id": "control", "type": "control" });
    return pages;
}

// Theme symbolic names to try, in order (D-26). Presets will later show their first widget's glyph; until then each page
// type has a placeholder.
const glyphChains = {
    "live": ["music-note-16th-symbolic", "audio-volume-high-symbolic", "media-playback-start-symbolic"],
    "control": ["configure-symbolic", "preferences-system-symbolic", "emblem-system-symbolic"],
    "small": ["window-symbolic", "view-grid-symbolic", "folder-symbolic"],
    "wide": ["view-split-left-right-symbolic", "view-grid-symbolic", "folder-symbolic"],
    "tall": ["view-split-top-bottom-symbolic", "view-grid-symbolic", "folder-symbolic"]
};

// "2×1": a page type's size in cells (D-48), for labels.
function cellLabel(type) {
    const c = cells[type] || cells.small;
    return c.w + "×" + c.h;
}



function indexOf(cycle, id) {
    for (let i = 0; i < cycle.length; ++i) {
        if (cycle[i].id === id)
            return i;
    }
    return -1;
}

// The page type Live is drawn as: one activity is Small, two or more Tall (LiveLayout.shape).
function liveType(activityCount) {
    return activityCount >= 2 ? "tall" : "small";
}

// geom: { cellW, cellH, controlW, controlH, controlEditW, controlEditH }. The bottom inset for the indicator and the Live
// chips lives inside a page's height (the host keeps content out of it), so it never changes a page's size.
function pageSize(type, geom) {
    if (type === "control")
        return { "w": geom.controlW, "h": geom.controlH };
    const c = cells[type] || cells.small;
    return { "w": c.w * geom.cellW, "h": c.h * geom.cellH };
}

// The window is sized once, before the deck shows: the largest width and the largest height in the cycle. Every page keeps
// room below it for the page-control capsule (its gap plus its height), because pages can come and go while the deck is
// open; the Control Center in edit mode hides the capsule, so it needs only its edit size. Live counts as Tall (its largest
// shape). The width is at least the capsule's. The notch's ears are added by the caller.
function windowSize(cycle, geom) {
    let w = geom.capsuleW;
    let h = 0;
    for (const page of cycle) {
        const size = page.type === "live" ? pageSize("tall", geom) : page.type === "control" ? { "w": geom.controlEditW, "h": Math.max(geom.controlEditH, geom.controlH + geom.capsuleExtra) } : pageSize(page.type, geom);
        w = Math.max(w, size.w);
        h = Math.max(h, page.type === "control" ? size.h : size.h + geom.capsuleExtra);
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

// The page-control capsule, left to right in deck order; null for a one-page deck. Live and the Control Center are glyphs
// (with their fallback chains), each preset a dot; the current page is flagged.
function indicator(cycle, currentId) {
    if (cycle.length < 2)
        return null;
    return cycle.map(page => ({
                "id": page.id,
                "kind": page.type === "live" || page.type === "control" ? "glyph" : "dot",
                "glyphs": glyphChains[page.type] || glyphChains.small,
                "current": page.id === currentId
            }));
}

// Pages move along the capsule's axis: +1 when `to` is further right than `from` (content slides left), -1 when further
// left (content slides right).
function direction(cycle, fromId, toId) {
    return indexOf(cycle, toId) >= indexOf(cycle, fromId) ? 1 : -1;
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

// A media or job change does not pop in while the deck is open (D-42 widened, D-51): Live already shows them. Notices
// and the keyboard layout still do (D-38).
function suppressesBump(kind, deckOpen) {
    return deckOpen && (kind === "media" || kind === "job");
}

// A page's content insets inside the visible body, the same in both shapes (the notch's ears sit outside the body): equal
// padding on every side; the Control Center keeps its own.
function insets(isControl, padding) {
    return isControl ? { "l": 14, "r": 14, "t": 12, "b": 16 } : { "l": padding, "r": padding, "t": padding, "b": padding };
}
