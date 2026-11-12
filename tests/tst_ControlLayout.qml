import QtQuick
import QtTest
import "../contents/ui/services"

TestCase {
    id: tc

    name: "ControlLayout"
    when: windowShown
    width: 400
    height: 300

    property var saved: []
    property var calls: []

    Item {
        id: host

        x: 10
        y: 20
        width: 300
        height: 200
    }

    Item {
        id: card

        x: 50
        y: 40
        width: 100
        height: 100
    }

    QtObject {
        id: page

        function previewControlDrop(x, y) { tc.calls.push("preview:" + x + "," + y); }
        function finishControlDrop(source, x, y) { tc.calls.push("finish:" + source.moduleId + ":" + x + "," + y); }
        function commitControlResize(source, w, h) { tc.calls.push("resize:" + source.moduleId + ":" + w + "x" + h); }
    }

    ControlLayout {
        id: layout

        storedJson: ""
        dragHost: host
        iconState: ({ "wifiEnabled": false, "batteryCharging": true, "powerProfileIcon": "battery-profile-performance" })
        onSaveRequested: json => tc.saved.push(json)
    }

    function init() {
        saved = [];
        calls = [];
        layout.storedJson = "";
        layout.editMode = false;
        layout.draft = [];
        layout.activePage = page;
    }

    function ids(list) {
        return list.map(m => m.id);
    }

    function test_never_saved_shows_the_default_and_ensure_stores_it() {
        compare(layout.currentLayout().length, layout.defaultLayout().length);
        layout.ensureLayout();
        compare(saved.length, 1);
        compare(JSON.parse(saved[0]).length, layout.defaultLayout().length);
        layout.storedJson = saved[0];
        layout.ensureLayout(); // already stored: nothing more to save
        compare(saved.length, 1);
    }

    function test_edit_session_dirty_cancel_and_save() {
        layout.beginEdit();
        verify(layout.editMode);
        verify(!layout.dirty);
        layout.removeModule(0);
        verify(layout.dirty);
        compare(layout.currentLayout().length, layout.defaultLayout().length - 1);
        layout.cancelEdit();
        verify(!layout.editMode);
        compare(saved.length, 0); // cancel never saves
        compare(layout.currentLayout().length, layout.defaultLayout().length);

        layout.beginEdit();
        layout.removeModule(0);
        layout.saveEdit();
        verify(!layout.editMode);
        compare(saved.length, 1);
        compare(JSON.parse(saved[0]).length, layout.defaultLayout().length - 1);
    }

    function test_saving_an_unchanged_edit_saves_nothing() {
        layout.beginEdit();
        layout.saveEdit();
        compare(saved.length, 0);
        verify(!layout.editMode);
    }

    function test_changes_outside_edit_mode_save_at_once() {
        layout.addModule("media");
        compare(saved.length, 0); // already in the default layout: no change
        layout.storedJson = JSON.stringify([{ "id": "volume", "w": 1, "h": 4, "v": 2 }]);
        layout.addModule("wifi");
        compare(saved.length, 1);
        compare(ids(JSON.parse(saved[0])), ["volume", "wifi"]);
    }

    function test_insert_remove_and_reset_in_a_draft() {
        layout.storedJson = JSON.stringify([{ "id": "volume", "w": 1, "h": 4, "v": 2 }, { "id": "media", "w": 6, "h": 3, "v": 2 }]);
        layout.beginEdit();
        layout.insertModule("wifi", 1);
        compare(ids(layout.currentLayout()), ["volume", "wifi", "media"]);
        layout.removeModule(5); // out of range: ignored
        compare(layout.currentLayout().length, 3);
        layout.resetLayout();
        compare(layout.currentLayout().length, layout.defaultLayout().length);
        layout.cancelEdit();
    }

    function test_module_icons_follow_the_icon_state() {
        compare(layout.moduleIcon("wifi"), "network-wireless-off");
        compare(layout.moduleIcon("batteryStatus"), "battery-charging");
        compare(layout.moduleIcon("powerMode"), "battery-profile-performance");
        compare(layout.moduleInfo("media").name, "Media");
    }

    function test_drag_previews_and_drops_into_the_active_page() {
        layout.beginEdit();
        const source = { "moduleId": "media" };
        layout.beginDrag(source, card, { "x": 5, "y": 5 }, 54);
        verify(layout.dragActive);
        compare(layout.dragIcon, "multimedia-player");
        compare(layout.dragX, 50 + 5 - 10 - 27); // card + mouse, into host coordinates, centred on the cursor
        layout.updateDrag(card, { "x": 10, "y": 10 });
        compare(calls[0], "preview:" + (50 + 10 - 10) + "," + (40 + 10 - 20));
        layout.dropCol = 3;
        layout.endDrag(card, { "x": 10, "y": 10 }, true);
        verify(!layout.dragActive);
        compare(layout.dropCol, -1);
        compare(calls[1], "finish:media:50,30");
        tryCompare(layout, "dragSource", null);
        layout.cancelEdit();
    }

    function test_drag_is_ignored_outside_edit_mode_and_cancel_drops_nothing() {
        layout.beginDrag({ "moduleId": "media" }, card, { "x": 1, "y": 1 }, 54);
        verify(!layout.dragActive);
        layout.beginEdit();
        layout.beginDrag({ "moduleId": "media" }, card, { "x": 1, "y": 1 }, 54);
        layout.endDrag(card, { "x": 1, "y": 1 }, false);
        compare(calls.length, 0);
        layout.cancelEdit();
    }

    function test_resize_clamps_and_commits_only_for_its_own_card() {
        layout.beginEdit();
        const source = { "moduleId": "notifications", "moduleIndex": 2, "moduleWidthUnits": 8, "moduleHeightUnits": 6 };
        layout.beginResize(source);
        verify(layout.resizeActive);
        compare(layout.resizeIndex, 2);
        layout.updateResize(source, 1, 1);
        compare(layout.resizeWidthUnits, 2); // notifications cannot shrink below 2x2
        compare(layout.resizeHeightUnits, 2);
        layout.updateResize({ "moduleId": "notifications" }, 5, 5); // another card: ignored
        compare(layout.resizeWidthUnits, 2);
        layout.endResize(source, true);
        compare(calls[0], "resize:notifications:2x2");
        verify(!layout.resizeActive);
        compare(layout.resizeIndex, -1);
        layout.cancelEdit();
    }

    function test_a_card_without_an_index_cannot_resize() {
        layout.beginEdit();
        layout.beginResize({ "moduleId": "media", "moduleIndex": -1 });
        verify(!layout.resizeActive);
        layout.cancelEdit();
    }

    function test_leaving_edit_mode_clears_any_drag_or_resize() {
        layout.beginEdit();
        layout.beginDrag({ "moduleId": "media" }, card, { "x": 1, "y": 1 }, 54);
        layout.dropOnPalette = true;
        layout.cancelEdit();
        verify(!layout.dragActive);
        verify(!layout.dropOnPalette);
        compare(layout.dragSource, null);
    }
}
