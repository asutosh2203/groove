.pragma library

// The Live page (D-51): what it shows for the running media and jobs. Pure functions of plain data.
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

// Full tiles whenever they fit, else a list: media + 1 job, or 2 jobs without media, fit.
function trayMode(hasMedia, jobCount) {
    if (jobCount === 0)
        return "none";
    return jobCount <= (hasMedia ? 1 : 2) ? "tiles" : "list";
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

// input: { hasMedia, jobs }. mediaSlot: media is the top card. trayArea: where the jobs go ("bottom" slot under media, the
// whole "page", or "top" for a lone job on the Small page).
function layout(input) {
    const jobs = order(input.jobs);
    const count = (input.hasMedia ? 1 : 0) + jobs.length;
    const mode = trayMode(input.hasMedia, jobs.length);
    return {
        "count": count,
        "shape": shape(count),
        "mediaSlot": input.hasMedia,
        "mode": mode,
        "jobs": jobs,
        "trayArea": mode === "none" ? "none" : input.hasMedia ? "bottom" : "page",
        "header": mode === "list" ? header(jobs) : null
    };
}

// The Live page's height in list mode (D-51): the media card (when shown, at its Small-page height), the header and the rows,
// plus the page's chrome (top inset and the bottom inset that holds the indicator), clamped between the Small and Tall
// heights. The list scrolls only past the Tall cap. Other modes keep the shape's own height: null.
// geom: { smallH, tallH, chrome, headerH, rowH, gap, mediaGap, expandedExtra } (mediaGap: the room around the hairline under
// the media card; expandedExtra: how much taller the open accordion row is than a compact one, 0 when none is open)
function fitHeight(layout, geom) {
    if (layout.mode !== "list")
        return null;
    const rows = layout.jobs.length;
    const media = layout.mediaSlot ? geom.smallH - geom.chrome + geom.mediaGap : 0;
    const content = media + geom.headerH + geom.gap + rows * geom.rowH + (rows - 1) * geom.gap + geom.expandedExtra;
    return Math.max(geom.smallH, Math.min(geom.tallH, geom.chrome + content));
}
