.pragma library

// D-62: the capsule scrub. Pure decisions; the capsule feeds it the pointer and runs what it returns.
// Items differ in width (glyphs and dots), so item boundaries are the midpoints between centres, never equal slices.

// rects: [{ x, w }] in capsule coordinates -> the centre of each item.
function centres(rects) {
    return rects.map(r => r.x + r.w / 2);
}

// The item whose cell contains x; clamps past either end. -1 with no items.
function pick(cs, x) {
    if (cs.length === 0)
        return -1;
    let i = 0;
    while (i < cs.length - 1 && x >= (cs[i] + cs[i + 1]) / 2)
        ++i;
    return i;
}

// The item under x only if x is within `half` of its centre (a plain click on the capsule's body does nothing), else -1.
function hit(cs, half, x) {
    const i = pick(cs, x);
    return i >= 0 && Math.abs(x - cs[i]) <= half ? i : -1;
}

function idle(index) {
    return { "scrubbing": false, "hover": index, "committed": index };
}

// dwell: 0 = every crossing switches the page at once; > 0 = the page switches once the pointer has rested that long on
// an item (or on release); Infinity = on release only (reduced motion).
// Returns { state, commit, timer }: commit is the item index to switch to (-1 none); timer is ms to (re)arm the rest
// timer, 0 to stop it, -1 to leave it running.
function move(s, index, dwell) {
    const next = { "scrubbing": true, "hover": index, "committed": s.committed };
    if (index === s.committed)
        return { "state": next, "commit": -1, "timer": 0 };
    if (dwell <= 0) {
        next.committed = index;
        return { "state": next, "commit": index, "timer": 0 };
    }
    if (dwell === Infinity)
        return { "state": next, "commit": -1, "timer": 0 };
    return { "state": next, "commit": -1, "timer": s.scrubbing && index === s.hover ? -1 : dwell };
}

// The rest timer fired.
function rest(s) {
    return { "state": { "scrubbing": s.scrubbing, "hover": s.hover, "committed": s.hover }, "commit": s.hover === s.committed ? -1 : s.hover, "timer": 0 };
}

// Release always commits to the item under the pointer.
function release(s) {
    return { "state": idle(s.hover), "commit": s.scrubbing && s.hover !== s.committed ? s.hover : -1, "timer": 0 };
}

// A pop-in, the capsule hiding or a lost grab: nothing pending is committed (pages already switched stay).
function cancel(s) {
    return { "state": idle(s.committed), "commit": -1, "timer": 0 };
}

// The cycle changed mid-scrub (DeckPlan.reconcile moved the deck): follow the deck's page, clamp the pointer's item.
function reconcile(s, count, currentIndex) {
    const last = Math.max(0, count - 1);
    return { "scrubbing": s.scrubbing, "hover": Math.min(Math.max(s.hover, 0), last), "committed": Math.min(Math.max(currentIndex, 0), last) };
}
