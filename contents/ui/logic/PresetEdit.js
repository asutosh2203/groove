.pragma library
.import "Catalogue.js" as Catalogue
.import "PageFit.js" as PageFit
.import "Presets.js" as Presets
.import "WidgetRegistry.js" as Registry

// The preset edit session's rules (D-56). A draft is { presets: [{ id, name, inCycle, page, placements }] }: a plain copy of
// the stored presets that the editor changes freely; nothing is stored until commit(). Every change returns
// { ok, draft, reason } and never mutates its input. Reasons: "cap", "nofit", "unknown", "invalid", "missing".

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function clone(v) {
    return JSON.parse(JSON.stringify(v));
}

function normalizePlacement(p) {
    const out = { "widget": p.widget, "span": p.span, "settings": isObject(p.settings) ? p.settings : {} };
    if (p.settingsVersion !== undefined)
        out.settingsVersion = p.settingsVersion;
    return out;
}

// The stored text as a draft. Unlike Presets.evaluate() nothing is hidden: a preset that does not fit still loads so it can
// be fixed. { readable, draft, error }: an unreadable blob (bad JSON, newer format) gives an empty draft that must not be
// saved over it.
function load(text) {
    const empty = readable => ({ "readable": readable, "draft": { "presets": [] }, "error": "" });
    if (String(text).trim().length === 0)
        return empty(true);
    const parsed = Presets.parse(text);
    if (!parsed.ok)
        return Object.assign(empty(false), { "error": parsed.error });
    const m = Presets.migrate(parsed.value);
    if (!m.ok)
        return Object.assign(empty(false), { "error": m.error });
    if (!Array.isArray(m.blob.presets))
        return Object.assign(empty(false), { "error": "the list is missing" });
    const presets = m.blob.presets.filter(p => isObject(p) && typeof p.id === "string" && Array.isArray(p.placements)).map(p => ({
        "id": p.id,
        "name": typeof p.name === "string" ? p.name : "",
        "inCycle": p.inCycle !== false,
        "page": String(p.page),
        "placements": p.placements.filter(q => isObject(q) && typeof q.widget === "string" && typeof q.span === "string").map(normalizePlacement)
    }));
    return { "readable": true, "draft": { "presets": presets }, "error": "" };
}

function dirty(original, draft) {
    return JSON.stringify(original) !== JSON.stringify(draft);
}

function index(draft, id) {
    return draft.presets.findIndex(p => p.id === id);
}

function spansOf(preset) {
    return preset.placements.map(p => p.span);
}

function fail(draft, reason, extra) {
    return Object.assign({ "ok": false, "draft": draft, "reason": reason }, extra || {});
}

// Applies fn to a copy of one preset; fn returns a reason string to refuse.
function edit(draft, id, fn) {
    const next = clone(draft);
    const i = index(next, id);
    if (i < 0)
        return fail(draft, "missing");
    const reason = fn(next.presets[i], next);
    return reason ? fail(draft, reason) : { "ok": true, "draft": next, "reason": "" };
}

function nextId(draft) {
    for (let n = 1; ; ++n) {
        if (index(draft, "p" + n) < 0)
            return "p" + n;
    }
}

function addPreset(draft) {
    if (draft.presets.length >= Presets.limit())
        return fail(draft, "cap");
    const next = clone(draft);
    next.presets.push({ "id": nextId(draft), "name": "", "inCycle": true, "page": "small", "placements": [] });
    return { "ok": true, "draft": next, "reason": "", "id": next.presets[next.presets.length - 1].id };
}

function removePreset(draft, id) {
    return edit(draft, id, (p, d) => {
        d.presets.splice(index(d, id), 1);
    });
}

function movePreset(draft, from, to) {
    if (from === to || from < 0 || to < 0 || from >= draft.presets.length || to >= draft.presets.length)
        return fail(draft, "missing");
    const next = clone(draft);
    next.presets.splice(to, 0, next.presets.splice(from, 1)[0]);
    return { "ok": true, "draft": next, "reason": "" };
}

function toggleCycle(draft, id) {
    return edit(draft, id, p => {
        p.inCycle = !p.inCycle;
    });
}

// Blocked (with the indexes that would not fit) when the placements do not fit the new type; nothing is ever removed.
function setPage(draft, id, type) {
    const i = index(draft, id);
    if (i < 0)
        return fail(draft, "missing");
    const check = PageFit.canSwitch(type, spansOf(draft.presets[i]));
    if (!check.ok)
        return fail(draft, "nofit", { "blocked": check.blocked });
    return edit(draft, id, p => {
        p.page = type;
    });
}

// index: the insertion index (a clicked cell's) or null for the first free spot.
function addPlacement(draft, id, widgetId, at, registry) {
    const manifest = registry.byId[widgetId];
    if (!manifest)
        return fail(draft, "unknown");
    const i = index(draft, id);
    if (i < 0)
        return fail(draft, "missing");
    const preset = draft.presets[i];
    const where = Catalogue.placeAt(preset.page, spansOf(preset), at, manifest);
    if (!where.ok)
        return fail(draft, "nofit");
    const r = edit(draft, id, p => {
        p.placements.splice(where.index, 0, { "widget": widgetId, "span": where.span, "settings": {}, "settingsVersion": manifest.version });
    });
    r.index = where.index;
    return r;
}

function removePlacement(draft, id, at) {
    return edit(draft, id, p => {
        if (at < 0 || at >= p.placements.length)
            return "missing";
        p.placements.splice(at, 1);
    });
}

function movePlacement(draft, id, from, to) {
    return edit(draft, id, p => {
        const spans = PageFit.move(p.page, spansOf(p), from, to);
        if (spans === null)
            return "nofit";
        p.placements.splice(to, 0, p.placements.splice(from, 1)[0]);
    });
}

function setSpan(draft, id, at, span, registry) {
    return edit(draft, id, p => {
        const placement = p.placements[at];
        const manifest = placement ? registry.byId[placement.widget] : null;
        if (!manifest)
            return "unknown";
        if (manifest.spans.indexOf(span) < 0)
            return "invalid";
        const spans = spansOf(p);
        spans[at] = span;
        if (!PageFit.fits(p.page, spans))
            return "nofit";
        placement.span = span;
    });
}

// A value the field would not accept (wrong type, outside its range, not an option) is refused, never coerced.
function setSetting(draft, id, at, key, value, registry) {
    return edit(draft, id, p => {
        const placement = p.placements[at];
        const manifest = placement ? registry.byId[placement.widget] : null;
        if (!manifest)
            return "unknown";
        const field = manifest.settings.find(f => f.key === key);
        if (!field || JSON.stringify(Registry.coerce(field, value)) !== JSON.stringify(value))
            return "invalid";
        placement.settings = Object.assign({}, Registry.migrate(manifest, placement.settings, placement.settingsVersion));
        placement.settings[key] = value;
        placement.settingsVersion = manifest.version;
    });
}

// What stops this draft being stored: [{ id, reason }]. A preset the display would hide is a blocker, so an invalid blob
// is never written.
function blockers(draft, registry) {
    const out = [];
    if (draft.presets.length > Presets.limit())
        out.push({ "id": "", "reason": "cap" });
    const seen = {};
    for (const p of draft.presets) {
        const why = seen[p.id] ? "duplicate id" : Presets.problem(p, registry);
        seen[p.id] = true;
        if (why !== "")
            out.push({ "id": p.id, "reason": why });
    }
    return out;
}

// { ok, json } or { ok: false, blockers }.
function commit(draft, registry) {
    const b = blockers(draft, registry);
    return b.length > 0 ? { "ok": false, "blockers": b } : { "ok": true, "json": Presets.serialize(draft.presets) };
}
