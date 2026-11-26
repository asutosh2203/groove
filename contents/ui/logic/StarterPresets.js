.pragma library
.import "PresetEdit.js" as PresetEdit

// The opt-in example page (D-69): one Wide preset named "Essentials" with a Clock, Weather, Pomodoro and System Monitor.
// It is built from the editor's own pure steps and checked by its own commit(), so it can never store what the deck
// would hide. Never touches an existing preset.

const NAME = "Essentials";
const PAGE = "wide";
const WIDGETS = ["clock", "weather", "pomodoro", "system-monitor"];

function name() {
    return NAME;
}

function widgets() {
    return WIDGETS.slice();
}

// ctx: { locked, draftKept }. locked: devPresets is set, so what is stored is not what shows. draftKept: the editor holds
// an unsaved draft whose Done would write over the page. Returns { state, id }; state is "ready", "exists" (id is the
// page), or why not: "locked", "draft", "unreadable", "cap", "unavailable".
function status(storedText, registry, ctx) {
    if (ctx.locked)
        return { "state": "locked", "id": "" };
    if (ctx.draftKept)
        return { "state": "draft", "id": "" };
    const loaded = PresetEdit.load(storedText);
    if (!loaded.readable)
        return { "state": "unreadable", "id": "" };
    const have = loaded.draft.presets.find(p => p.name === NAME);
    if (have)
        return { "state": "exists", "id": have.id };
    if (loaded.draft.presets.length >= PresetEdit.limit())
        return { "state": "cap", "id": "" };
    if (!WIDGETS.some(id => registry.byId[id]))
        return { "state": "unavailable", "id": "" };
    return { "state": "ready", "id": "" };
}

// Returns { state, id, json }. "added" carries the blob to store and the new page's id; "exists" the page to go to; any
// other state is a refusal (see status) or "problem" when the result would not pass the editor's checks.
function add(storedText, registry, ctx) {
    const now = status(storedText, registry, ctx);
    if (now.state !== "ready")
        return { "state": now.state, "id": now.id, "json": "" };
    const created = PresetEdit.addPreset(PresetEdit.load(storedText).draft);
    if (!created.ok)
        return { "state": created.reason, "id": "", "json": "" };
    let draft = created.draft;
    const paged = PresetEdit.setPage(draft, created.id, PAGE);
    if (!paged.ok)
        return { "state": "problem", "id": "", "json": "" };
    draft = JSON.parse(JSON.stringify(paged.draft));
    draft.presets[PresetEdit.index(draft, created.id)].name = NAME;
    for (const id of WIDGETS.filter(w => registry.byId[w])) {
        const placed = PresetEdit.addPlacement(draft, created.id, id, null, registry);
        if (!placed.ok)
            return { "state": "problem", "id": "", "json": "" };
        draft = placed.draft;
    }
    const stored = PresetEdit.commit(draft, registry);
    return stored.ok ? { "state": "added", "id": created.id, "json": stored.json } : { "state": "problem", "id": "", "json": "" };
}
