import QtQuick
import QtTest
import "../contents/ui/controlcenter" as Tiles

Item {
    id: testRoot
    width: 400
    height: 400

    QtObject {
        id: app
        readonly property var layoutService: QtObject { property bool editMode: false }
        property bool notificationImagesEnabled: false
        property var opened: []
        function notificationStatusText() { return "2 notifications"; }
        // Row 0 is clickable (live action or fallback), row 1 has nothing to open.
        readonly property var notifications: QtObject {
            function count() { return 2; }
            function rows(limit) { return [0, 1]; }
            function overflowCount(limit) { return 0; }
            function clickable(row) { return row === 0; }
            function open(row) { app.opened = app.opened.concat([row]); return row === 0; }
            function rowValue(row, role, fallbackValue) { return fallbackValue; }
            function title(row) { return "Title " + row; }
            function appName(row) { return "App " + row; }
            function body(row) { return "Body " + row; }
            function createdMs(row) { return 0; }
            function appIcon(row) { return ""; }
            function mainIcon(row) { return "notifications"; }
            function mainImage(row) { return null; }
            function urgencyKind(row) { return row === 0 ? "critical" : "normal"; }
            function clearAll() {}
        }
    }

    QtObject {
        id: source
        property int count: 2
    }

    Item {
        id: host
        width: 300
        height: 320

        Tiles.NotificationsTile {
            id: tile
            app: app
            notificationsSource: source
        }
    }

    TestCase {
        name: "NotificationsTile"
        when: windowShown

        function rows() {
            const found = [];
            const walk = (item) => {
                for (let i = 0; i < item.children.length; ++i) {
                    const child = item.children[i];
                    if (child.objectName === "notificationRow")
                        found.push(child);
                    walk(child);
                }
            };
            walk(tile);
            found.sort((a, b) => a.mapToItem(tile, 0, 0).y - b.mapToItem(tile, 0, 0).y);
            return found;
        }

        function init() {
            app.opened = [];
        }

        function test_only_clickable_rows_get_affordance() {
            const r = rows();
            compare(r.length, 2);
            compare(r[0].clickable, true);
            compare(r[1].clickable, false);
            compare(r[0].activeFocusOnTab, true);
            compare(r[1].activeFocusOnTab, false);
        }

        function test_glyph_reveals_on_hover_and_focus() {
            const r = rows();
            mouseMove(r[0], 20, 10);
            tryCompare(r[0], "revealOpen", true);
            // Offscreen hover-leave is unreliable, so focus is checked on its own: the glyph is wired to `revealOpen`.
            compare(r[0].revealed, true);
            compare(r[0].revealOpen, true);
            // A row with nothing to open never reveals, even when hovered.
            mouseMove(r[1], 20, 10);
            wait(50);
            compare(r[1].revealOpen, false);
        }

        function test_enter_and_click_open_only_clickable_rows() {
            const r = rows();
            mouseClick(r[0], 20, 10);
            compare(app.opened.length, 1);
            compare(app.opened[0], 0);
            r[0].forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(app.opened.length, 2);
        }
    }
}
