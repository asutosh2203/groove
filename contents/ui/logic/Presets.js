.pragma library

// Presets (D-54): the stored blob, its validation and migrations, and the page grid. Pure functions of plain data.
// The blob is { format, presets: [{ id, name, inCycle, page, placements: [{ widget, span, settingsVersion, settings }] }] }.
// Validation decides what is shown; it never rewrites what is stored, so the preset editor (D3) can still show and fix it.

const FORMAT = 1;
const MAX_PRESETS = 3;
const pages = { "small": { "cols": 2, "rows": 1 }, "wide": { "cols": 4, "rows": 1 }, "tall": { "cols": 2, "rows": 2 } };
const spanCols = { "1x1": 1, "2x1": 2, "4x1": 4 };

// Per format: step(blob) lifts a blob from that format to the next. None yet; the loop in migrate() is the framework.
const migrations = {};

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Placements fill the page in order, row by row. spans: ["1x1", ...]. Returns [{ col, row, cols }] or null when a span is
// wider than the page or the content does not fit its rows.
function pack(page, spans) {
    const grid = pages[page];
    if (!grid)
        return null;
    const out = [];
    let col = 0;
    let row = 0;
    for (const span of spans) {
        const cols = spanCols[span];
        if (cols === undefined || cols > grid.cols)
            return null;
        if (col + cols > grid.cols) {
            col = 0;
            row += 1;
        }
        if (row >= grid.rows)
            return null;
        out.push({ "col": col, "row": row, "cols": cols });
        col += cols;
        if (col >= grid.cols) {
            col = 0;
            row += 1;
        }
    }
    return out;
}

// Pixel boxes for packed cells inside a page content area of w x h.
function boxes(page, w, h, gap, packed) {
    const grid = pages[page];
    if (!grid || !packed)
        return [];
    const cw = (w - gap * (grid.cols - 1)) / grid.cols;
    const ch = (h - gap * (grid.rows - 1)) / grid.rows;
    return packed.map(p => ({ "x": p.col * (cw + gap), "y": p.row * (ch + gap), "w": p.cols * cw + (p.cols - 1) * gap, "h": ch }));
}

function parse(text) {
    try {
        return { "ok": true, "value": JSON.parse(text), "error": "" };
    } catch (e) {
        return { "ok": false, "value": null, "error": "not valid JSON (" + e.message + ")" };
    }
}

// Lifts a parsed blob to the current format. Returns { ok, blob, error }.
function migrate(blob) {
    if (!isObject(blob) || !Number.isInteger(blob.format) || blob.format < 1)
        return { "ok": false, "blob": null, "error": "no format number" };
    if (blob.format > FORMAT)
        return { "ok": false, "blob": null, "error": "format " + blob.format + " is newer than this version understands (" + FORMAT + ")" };
    let current = blob;
    while (current.format < FORMAT) {
        const step = migrations[current.format];
        if (!step)
            return { "ok": false, "blob": null, "error": "no migration from format " + current.format };
        current = step(current);
    }
    return { "ok": true, "blob": current, "error": "" };
}

// One preset against the registry ({ byId }). Returns "" when it can be shown, else why not.
function problem(preset, registry) {
    if (!isObject(preset) || typeof preset.id !== "string" || preset.id.length === 0)
        return "no id";
    if (preset.id === "live" || preset.id === "control")
        return "the id " + preset.id + " is reserved";
    if (!pages[preset.page])
        return "page must be small, wide or tall";
    if (!Array.isArray(preset.placements))
        return "placements must be a list";
    for (const p of preset.placements) {
        if (!isObject(p) || typeof p.widget !== "string" || spanCols[p.span] === undefined)
            return "a placement needs a widget and a span (1x1, 2x1 or 4x1)";
        const manifest = registry.byId[p.widget];
        if (manifest && manifest.spans.indexOf(p.span) < 0)
            return p.widget + " does not support " + p.span;
    }
    if (pack(preset.page, preset.placements.map(p => p.span)) === null)
        return "the placements do not fit a " + preset.page + " page";
    return "";
}

// text: the blob as stored. Returns { presets, hidden, log }: the presets that show (at most three, in order, with their
// grid cells), the ones that do not and why, and log lines for a developer. A bad blob gives no presets.
function evaluate(text, registry) {
    const none = reason => ({ "presets": [], "hidden": [], "log": reason ? [reason] : [] });
    if (String(text).trim().length === 0)
        return none("");
    const parsed = parse(text);
    if (!parsed.ok)
        return none("presets: " + parsed.error);
    const m = migrate(parsed.value);
    if (!m.ok)
        return none("presets: " + m.error);
    if (!Array.isArray(m.blob.presets))
        return none("presets: the list is missing");
    const out = { "presets": [], "hidden": [], "log": [] };
    const seen = {};
    for (const preset of m.blob.presets) {
        const id = isObject(preset) ? String(preset.id) : "?";
        let why = problem(preset, registry);
        if (why === "" && seen[id])
            why = "duplicate id";
        if (why === "" && out.presets.length >= MAX_PRESETS)
            why = "more than " + MAX_PRESETS + " presets";
        if (why !== "") {
            out.hidden.push({ "id": id, "reason": why });
            out.log.push("preset " + id + " not shown: " + why);
            continue;
        }
        seen[id] = true;
        const packed = pack(preset.page, preset.placements.map(p => p.span));
        out.presets.push({
                             "id": id,
                             "name": typeof preset.name === "string" ? preset.name : id,
                             "type": preset.page,
                             "inCycle": preset.inCycle !== false,
                             "placements": preset.placements.map((p, i) => ({
                                                                         "widget": p.widget,
                                                                         "span": p.span,
                                                                         "settings": isObject(p.settings) ? p.settings : {},
                                                                         "settingsVersion": p.settingsVersion,
                                                                         "col": packed[i].col,
                                                                         "row": packed[i].row,
                                                                         "cols": packed[i].cols
                                                                     }))
                         });
    }
    return out;
}

// The blob to store for these presets (the editor's draft). Never called with a preset that has a problem(): the editor
// checks first, so an invalid blob is never written.
function serialize(presets) {
    return JSON.stringify({ "format": FORMAT, "presets": presets });
}

function limit() {
    return MAX_PRESETS;
}

// A page type's size in cells, or null.
function gridOf(page) {
    return pages[page] || null;
}
