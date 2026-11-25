import QtQuick
import QtTest
import "../contents/ui/services" as Services
import "../contents/ui/logic/WidgetRegistry.js" as Registry
import "../contents/ui/widgets/Manifests.js" as Manifests

// D-56: the edit session. One draft for the presets and the Control Center layout, saved only by Done, kept when the deck
// closes with unsaved changes, locked while devPresets is set, and stepped back one level at a time.
Item {
    id: testRoot

    width: 100
    height: 100

    property var saved: []
    property string stored: JSON.stringify({ "format": 1, "presets": [
        { "id": "a", "name": "", "page": "small", "placements": [{ "widget": "clock", "span": "1x1", "settings": {} }] },
        { "id": "b", "name": "", "page": "tall", "placements": [] }] })

    QtObject {
        id: fakeLayout

        property bool dirty: false
        property int begins: 0
        property int saves: 0
        property int cancels: 0

        function beginEdit() { begins++; }
        function saveEdit() { saves++; }
        function cancelEdit() { cancels++; dirty = false; }
    }

    Services.PresetEditor {
        id: editor

        storedPresets: testRoot.stored
        devPresets: ""
        registry: Registry.build(Manifests.list)
        layout: fakeLayout
        onSaveRequested: json => testRoot.saved.push(json)
    }

    TestCase {
        name: "PresetEditor"
        when: windowShown

        function init() {
            editor.exit();
            editor.devPresets = "";
            testRoot.stored = JSON.stringify({ "format": 1, "presets": [
                { "id": "a", "name": "", "page": "small", "placements": [{ "widget": "clock", "span": "1x1", "settings": {} }] },
                { "id": "b", "name": "", "page": "tall", "placements": [] }] });
            testRoot.saved = [];
            fakeLayout.dirty = false;
            fakeLayout.begins = 0;
            fakeLayout.saves = 0;
            fakeLayout.cancels = 0;
        }

        function test_begin_starts_on_the_tile_editor_with_a_clean_draft() {
            editor.begin("gear");
            verify(editor.active);
            compare(editor.view, "gear");
            compare(fakeLayout.begins, 1);
            compare(editor.presetCount, 2);
            verify(!editor.dirty);
        }

        function test_cancel_without_changes_closes_without_asking() {
            editor.begin("gear");
            editor.requestCancel();
            verify(!editor.active);
            verify(!editor.promptOpen);
            compare(fakeLayout.cancels, 1);
        }

        function test_changes_ask_first_and_esc_steps_back_one_level_at_a_time() {
            editor.begin("preset");
            editor.openForm(0);
            compare(editor.pane, "form");
            editor.setPage("wide");
            verify(editor.dirty);
            editor.stepBack();
            compare(editor.pane, "grid");
            verify(editor.active);
            editor.stepBack();
            verify(editor.promptOpen);
            editor.stepBack();
            verify(!editor.promptOpen);
            verify(editor.active);
            editor.requestCancel();
            editor.discard();
            verify(!editor.active);
            compare(editor.presetCount, 2);
        }

        function test_a_layout_change_alone_counts_as_unsaved() {
            editor.begin("gear");
            fakeLayout.dirty = true;
            verify(editor.dirty);
            editor.requestCancel();
            verify(editor.promptOpen);
        }

        function test_done_saves_presets_and_layout_once() {
            editor.begin("preset");
            editor.setPage("wide");
            editor.done();
            compare(testRoot.saved.length, 1);
            compare(JSON.parse(testRoot.saved[0]).presets[0].page, "wide");
            compare(fakeLayout.saves, 1);
            verify(!editor.active);
        }

        function test_done_with_no_preset_changes_writes_no_blob() {
            editor.begin("gear");
            editor.done();
            compare(testRoot.saved.length, 0);
            compare(fakeLayout.saves, 1);
        }

        function test_devPresets_locks_the_presets_but_not_the_layout() {
            editor.devPresets = JSON.stringify({ "format": 1, "presets": [{ "id": "dev", "name": "", "page": "small", "placements": [] }] });
            editor.begin("preset");
            verify(editor.locked);
            compare(editor.presetId, "dev");
            editor.setPage("wide");
            editor.done();
            compare(testRoot.saved.length, 0);
            compare(fakeLayout.saves, 1);
        }

        function test_an_unreadable_blob_is_never_written_over() {
            testRoot.stored = "{nope";
            editor.begin("gear");
            verify(!editor.readable);
            editor.addPreset();
            editor.done();
            compare(testRoot.saved.length, 0);
            compare(editor.hint, "unreadable");
            verify(editor.active);
        }

        function test_closing_the_deck_keeps_unsaved_changes_and_the_next_open_resumes_them() {
            editor.begin("preset");
            editor.setPage("wide");
            editor.suspend();
            verify(!editor.active);
            verify(editor.kept);
            compare(fakeLayout.cancels, 0);
            editor.resumeIfKept();
            verify(editor.active);
            verify(editor.restoredNote);
            compare(editor.pageType, "wide");
            compare(fakeLayout.begins, 1);
            editor.setPage("small");
            verify(!editor.restoredNote);
        }

        function test_closing_the_deck_with_nothing_to_lose_ends_the_session() {
            editor.begin("preset");
            editor.suspend();
            verify(!editor.active);
            verify(!editor.kept);
            compare(fakeLayout.cancels, 1);
        }

        function test_the_cap_blocks_a_fourth_preset_and_delete_is_staged() {
            editor.begin("gear");
            editor.addPreset();
            compare(editor.presetCount, 3);
            verify(!editor.canAddPreset);
            editor.addPreset();
            compare(editor.hint, "cap");
            compare(editor.presetCount, 3);
            editor.removePreset("a");
            compare(editor.presetCount, 2);
            compare(testRoot.saved.length, 0);
            editor.discard();
            editor.begin("gear");
            compare(editor.presetCount, 2);
            compare(editor.draft.presets[0].id, "a");
        }

        function test_removing_the_viewed_preset_moves_to_a_neighbour_or_the_tile_editor() {
            editor.begin("preset");
            compare(editor.presetId, "a");
            editor.removePreset("a");
            compare(editor.presetId, "b");
            editor.removePreset("b");
            compare(editor.view, "gear");
        }

        function test_a_page_type_the_widgets_do_not_fit_is_blocked_with_a_hint() {
            testRoot.stored = JSON.stringify({ "format": 1, "presets": [{ "id": "a", "name": "", "page": "wide", "placements": [{ "widget": "weather", "span": "4x1", "settings": {} }] }] });
            editor.begin("preset");
            editor.setPage("small");
            compare(editor.pageType, "wide");
            compare(editor.hint, "nofit");
            verify(!editor.dirty);
        }

        function enumBlob() {
            return JSON.stringify({ "format": 1, "presets": [
                { "id": "w", "name": "", "page": "small", "placements": [{ "widget": "weather", "span": "1x1", "settings": {} }, { "widget": "clock", "span": "1x1", "settings": {} }] }] });
        }

        // D-64: an enum field opens a picker page; a pick is stored and slides back, Esc or ‹ changes nothing.
        function test_a_weather_enum_picks_through_the_picker_and_slides_back() {
            testRoot.stored = enumBlob();
            editor.begin("preset");
            editor.openForm(0);
            editor.openPicker("units");
            compare(editor.pickerKey, "units");
            compare(editor.pickerLabel, "Units");
            editor.pick("fahrenheit");
            compare(editor.pickerKey, "");
            compare(editor.pane, "form");
            compare(editor.placement.settings.units, "fahrenheit");
            verify(editor.dirty);
        }

        function test_a_clock_enum_works_the_same_way() {
            testRoot.stored = enumBlob();
            editor.begin("preset");
            editor.openForm(1);
            editor.openPicker("timeFormat");
            verify(editor.pickerField !== null);
            editor.pick("24h");
            compare(editor.placement.settings.timeFormat, "24h");
            compare(editor.pickerKey, "");
        }

        function test_back_and_esc_leave_the_picker_without_a_change() {
            testRoot.stored = enumBlob();
            editor.begin("preset");
            editor.openForm(0);
            editor.openPicker("detail");
            editor.stepBack();
            compare(editor.pickerKey, "");
            compare(editor.pane, "form", "Esc closes the picker first, not the form");
            verify(!editor.dirty);
            editor.openPicker("detail");
            editor.closePicker();
            verify(!editor.dirty);
            editor.stepBack();
            compare(editor.pane, "grid");
        }

        function test_leaving_the_form_forgets_an_open_picker() {
            testRoot.stored = enumBlob();
            editor.begin("preset");
            editor.openForm(0);
            editor.openPicker("units");
            editor.backToGrid();
            compare(editor.pickerKey, "");
            editor.openForm(0);
            compare(editor.pickerKey, "");
        }
    }
}
