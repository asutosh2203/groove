pragma ComponentBehavior: Bound

import QtQuick
import "../logic/PresetEdit.js" as PresetEdit
import "../logic/WidgetRegistry.js" as Registry

// The deck's edit mode (D-56): one session for the presets and the Control Center layout. The rules are pure
// (logic/PresetEdit.js); this object holds the draft and what the editor shows. Nothing is stored until done(): the
// presets leave through saveRequested, the layout through the layout service's own save. Closing the deck with unsaved
// changes keeps the draft in memory (suspend) and the next deck open resumes it.
QtObject {
    id: editor

    required property string storedPresets
    required property string devPresets
    required property var registry
    required property var layout

    signal saveRequested(string json)

    property bool active: false
    property bool kept: false
    property bool restoredNote: false
    // "gear": the Control Center tile editor; "preset": the grid and form of presetId.
    property string view: "gear"
    property string presetId: ""
    // "grid" or "form"; the form edits the placement at formIndex.
    property string pane: "grid"
    property int formIndex: -1
    // The free cell chosen for "Add widget" (the insertion index a widget put there would take), or -1.
    property int cellIndex: -1
    property bool promptOpen: false
    // Why the last change or save was refused: "nofit", "cap", "unreadable" or a preset id's problem; "" when none.
    property string hint: ""
    property var original: ({ "presets": [] })
    property var draft: ({ "presets": [] })
    property bool readable: true
    property bool fieldFocused: false

    readonly property bool locked: editor.devPresets.trim().length > 0
    readonly property bool presetsDirty: PresetEdit.dirty(editor.original, editor.draft)
    readonly property bool dirty: (editor.active || editor.kept) && (editor.presetsDirty || editor.layout.dirty)
    readonly property int presetIndex: PresetEdit.index(editor.draft, editor.presetId)
    readonly property var preset: editor.presetIndex >= 0 ? editor.draft.presets[editor.presetIndex] : null
    readonly property int presetCount: editor.draft.presets.length
    readonly property int maxPresets: PresetEdit.limit()
    readonly property bool canAddPreset: editor.presetCount < editor.maxPresets
    readonly property string pageType: editor.preset ? editor.preset.page : "small"
    readonly property var placement: editor.preset && editor.formIndex >= 0 ? editor.preset.placements[editor.formIndex] || null : null

    // Where a placed or offered widget's name comes from: its manifest, in the user's language.
    function widgetName(id) {
        return editor.registry.byId[id] ? Registry.text(editor.registry.byId[id].name, Qt.locale().name) : "";
    }

    // The places the draft's Weather widgets use, for the weather hub (a place picked but not saved still needs data).
    readonly property var weatherLocations: editor.active ? PresetEdit.weatherLocations(editor.draft, editor.registry) : []

    function apply(result) {
        editor.hint = result.ok ? "" : result.reason;
        if (!result.ok)
            return false;
        editor.draft = result.draft;
        editor.restoredNote = false;
        return true;
    }

    // Enter from the Control Center's pencil (D-56): on the tile editor. Resumes a kept draft instead of starting over.
    function begin(start) {
        if (editor.kept) {
            editor.kept = false;
            editor.restoredNote = true;
            editor.active = true;
            return;
        }
        const stored = PresetEdit.load(editor.storedPresets);
        editor.original = stored.draft;
        editor.draft = stored.draft;
        editor.readable = stored.readable;
        editor.hint = stored.readable ? "" : "unreadable";
        editor.restoredNote = false;
        editor.promptOpen = false;
        editor.pane = "grid";
        editor.formIndex = -1;
        editor.layout.beginEdit();
        editor.view = start === "preset" && stored.draft.presets.length > 0 ? "preset" : "gear";
        editor.presetId = stored.draft.presets.length > 0 ? stored.draft.presets[0].id : "";
        editor.active = true;
    }

    function resumeIfKept() {
        if (editor.kept)
            editor.begin("");
    }

    function selectPreset(id) {
        editor.view = "preset";
        editor.cellIndex = -1;
        editor.presetId = id;
        editor.pane = "grid";
        editor.formIndex = -1;
        editor.hint = "";
    }

    function selectGear() {
        editor.view = "gear";
        editor.pane = "grid";
        editor.formIndex = -1;
        editor.hint = "";
    }

    function openForm(index) {
        editor.formIndex = index;
        editor.pane = "form";
        editor.hint = "";
    }

    function backToGrid() {
        editor.pane = "grid";
        editor.formIndex = -1;
    }

    function setPage(type) {
        editor.apply(PresetEdit.setPage(editor.draft, editor.presetId, type));
    }

    function setSpan(span) {
        editor.apply(PresetEdit.setSpan(editor.draft, editor.presetId, editor.formIndex, span, editor.registry));
    }

    function setSetting(key, value) {
        editor.apply(PresetEdit.setSetting(editor.draft, editor.presetId, editor.formIndex, key, value, editor.registry));
    }

    // "+ New": a blank Small preset, shown at once.
    function addPreset() {
        const result = PresetEdit.addPreset(editor.draft);
        if (editor.apply(result))
            editor.selectPreset(result.id);
    }

    // Staged until Done (cancel brings it back). The editor moves to a neighbour, or to the tile editor when none is left.
    function removePreset(id) {
        const at = PresetEdit.index(editor.draft, id);
        if (!editor.apply(PresetEdit.removePreset(editor.draft, id)) || editor.presetId !== id)
            return;
        const left = editor.draft.presets;
        if (left.length === 0)
            editor.selectGear();
        else
            editor.selectPreset(left[Math.min(at, left.length - 1)].id);
    }

    function toggleCycle(id) {
        editor.apply(PresetEdit.toggleCycle(editor.draft, id));
    }

    function movePreset(from, to) {
        editor.apply(PresetEdit.movePreset(editor.draft, from, to));
    }

    // A click on a free cell chooses it for the catalogue; a second click lets go.
    function pickCell(index) {
        editor.cellIndex = editor.cellIndex === index ? -1 : index;
    }

    // `at` is the insertion index (a cell's), or null for the first free spot that fits.
    function addWidget(widgetId, at) {
        if (editor.apply(PresetEdit.addPlacement(editor.draft, editor.presetId, widgetId, at, editor.registry)))
            editor.cellIndex = -1;
    }

    function moveWidget(from, to) {
        editor.apply(PresetEdit.movePlacement(editor.draft, editor.presetId, from, to));
    }

    function removePlacement(index) {
        if (editor.apply(PresetEdit.removePlacement(editor.draft, editor.presetId, index)) && editor.pane === "form")
            editor.backToGrid();
    }

    function exit() {
        editor.active = false;
        editor.kept = false;
        editor.promptOpen = false;
        editor.restoredNote = false;
        editor.pane = "grid";
        editor.formIndex = -1;
    }

    function discard() {
        editor.layout.cancelEdit();
        editor.draft = editor.original;
        editor.exit();
    }

    // The ✕: asks first when there is something to lose.
    function requestCancel() {
        if (editor.dirty)
            editor.promptOpen = true;
        else
            editor.discard();
    }

    // The ✓. Presets are written only through a blob that passes the display's own checks, and never while devPresets
    // is set (it would win over what is saved) or when the stored blob could not be read (it would overwrite it).
    function done() {
        if (editor.presetsDirty && !editor.locked) {
            if (!editor.readable) {
                editor.hint = "unreadable";
                return;
            }
            const result = PresetEdit.commit(editor.draft, editor.registry);
            if (!result.ok) {
                editor.hint = result.blockers[0].reason === "cap" ? "cap" : "problem";
                return;
            }
            editor.saveRequested(result.json);
        }
        editor.layout.saveEdit();
        editor.exit();
    }

    // Esc steps back one level (D-56). A focused text field has already had its turn.
    function stepBack() {
        if (editor.promptOpen)
            editor.promptOpen = false;
        else if (editor.pane === "form")
            editor.backToGrid();
        else
            editor.requestCancel();
    }

    // The deck is closing. Unsaved changes stay in memory for the next open; otherwise the session ends.
    function suspend() {
        if (!editor.active)
            return;
        if (editor.dirty) {
            editor.active = false;
            editor.kept = true;
            editor.promptOpen = false;
        } else {
            editor.discard();
        }
    }
}
