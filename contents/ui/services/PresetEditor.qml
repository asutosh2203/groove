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
