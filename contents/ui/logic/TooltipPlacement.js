.pragma library

// Where a tooltip goes so that it stays inside its window: the island's dialog clips whatever sticks out of it. owner is
// { x, y, w, h } in window coordinates, tip and win are { w, h } (a win side of 0 or less means unknown: no limit there).
// Returns { x, y, above } with the position relative to the owner. Above is preferred; below when there is no room above.
function place(owner, tip, win, margin, gap) {
    let x = Math.round((owner.w - tip.w) / 2);
    if (win.w > 0) {
        x = Math.min(x, win.w - margin - tip.w - owner.x);
        x = Math.max(x, margin - owner.x);
    }
    const roomAbove = owner.y - gap - margin;
    const roomBelow = win.h - margin - (owner.y + owner.h + gap);
    const above = win.h <= 0 || tip.h <= roomAbove || (tip.h > roomBelow && roomAbove >= roomBelow);
    return { "x": x, "y": above ? -gap - tip.h : owner.h + gap, "above": above };
}
