.pragma library

// The Live page (D-52, D-57): what it shows for the running media, agents and jobs. Pure functions of plain data.
// An agent session (Agents.js) is ordered already (waiting, working, done) and sits above the file jobs. Both appear in
// `items` as { id, kind: "agent"|"job", ... }; an agent's id is "agent:<session id>", unique among job ids.
// A job is { id, row, created, percent, processed, total, remaining, kind }: percent 0..100 or -1, bytes 0 when unknown,
// remaining whole seconds or -1, kind from Jobs.kind.

// Newest first by creation time; the row breaks a tie so the order is stable.
function order(jobs) {
    return jobs.slice().sort((a, b) => b.created - a.created || a.row - b.row);
}

// One activity is a Small page, two or more a Tall page (two fixed 2x1 slots).
function shape(count) {
    return count >= 2 ? "tall" : "small";
}

// Full tiles whenever they fit, else a list: media + 1 item, or 2 items without media, fit (an item is an agent or a job).
function trayMode(hasMedia, itemCount) {
    if (itemCount === 0)
        return "none";
    return itemCount <= (hasMedia ? 1 : 2) ? "tiles" : "list";
}

// Byte-weighted combined percent when every job reports its size, else the plain mean of the known percentages, else -1.
function combinedPercent(jobs) {
    if (jobs.length === 0)
        return -1;
    if (jobs.every(j => j.total > 0)) {
        let done = 0;
        let all = 0;
        for (const j of jobs) {
            done += Math.min(j.processed, j.total);
            all += j.total;
        }
        return Math.round(done / all * 100);
    }
    const known = jobs.filter(j => j.percent >= 0);
    return known.length === 0 ? -1 : Math.round(known.reduce((sum, j) => sum + j.percent, 0) / known.length);
}

// The longest remaining time of any job, -1 when none knows it.
function longestRemaining(jobs) {
    return jobs.reduce((max, j) => Math.max(max, j.remaining), -1);
}

// The list's summary header: one kind for all jobs gives the kind's noun and glyph; otherwise a generic "transfers"
// header and every row carries its own glyph. A generic kind is not a noun, so it reads as mixed.
function header(jobs) {
    const kinds = new Set(jobs.map(j => j.kind));
    const same = kinds.size === 1 && !kinds.has("generic");
    return {
        "kind": same ? jobs[0].kind : "mixed",
        "count": jobs.length,
        "percent": combinedPercent(jobs),
        "remaining": longestRemaining(jobs),
        "rowGlyphs": !same
    };
}

// input: { hasMedia, jobs, agents }. mediaSlot: media is the top card. trayArea: where the items go ("bottom" slot under
// media, the whole "page", or "top" for a lone item on the Small page). The list header summarises the file jobs only.
function layout(input) {
    const jobs = order(input.jobs);
    const agents = input.agents || [];
    const items = agents.map(a => ({ "id": "agent:" + a.id, "kind": "agent", "sid": a.id })).concat(jobs.map(j => ({ "id": j.id, "kind": "job", "row": j.row, "job": j })));
    const count = (input.hasMedia ? 1 : 0) + items.length;
    const mode = trayMode(input.hasMedia, items.length);
    return {
        "count": count,
        "shape": shape(count),
        "mediaSlot": input.hasMedia,
        "mode": mode,
        "jobs": jobs,
        "agents": agents,
        "items": items,
        "trayArea": mode === "none" ? "none" : input.hasMedia ? "bottom" : "page",
        "header": mode === "list" && jobs.length > 0 ? header(jobs) : null
    };
}

// The Live page's height in list mode (D-52): the media card (when shown, at its Small-page height), the header and the rows,
// plus the page's chrome (top inset and the bottom inset that holds the indicator), clamped between the Small and Tall
// heights. The list scrolls only past the Tall cap. Other modes keep the shape's own height: null.
// geom: { smallH, tallH, chrome, headerH, rowH, gap, mediaGap, expandedExtra } (mediaGap: the room around the hairline under
// the media card; expandedExtra: how much taller the open accordion row is than a compact one, 0 when none is open)
function fitHeight(layout, geom) {
    if (layout.mode !== "list")
        return null;
    const rows = layout.items.length;
    const media = layout.mediaSlot ? geom.smallH - geom.chrome + geom.mediaGap : 0;
    const parts = rows + (layout.header ? 1 : 0);  // the rows, plus the header when file jobs exist
    const content = media + (layout.header ? geom.headerH : 0) + rows * geom.rowH + (parts - 1) * geom.gap + geom.expandedExtra;
    return Math.max(geom.smallH, Math.min(geom.tallH, geom.chrome + content));
}
