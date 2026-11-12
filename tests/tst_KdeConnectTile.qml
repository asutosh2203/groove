import QtQuick
import QtTest
import "../contents/ui/controlcenter" as Tiles
import "../contents/ui/controlcenter/KdeConnectState.js" as K

Item {
    id: testRoot
    width: 400
    height: 300

    QtObject {
        id: app
        property bool controlEditMode: false
        property var paired: []
        property var connected: []
        property string lastAction: ""
        function cleanText(t) { return String(t === undefined || t === null ? "" : t).trim(); }
        function kdeConnectDevices(limit) {
            const all = K.buildDevices(paired, connected);
            return limit > 0 ? all.slice(0, limit) : all;
        }
        function kdeConnectReachableCount() { return K.connectedCount(kdeConnectDevices(0)); }
        function kdeConnectSummary() { return K.summaryKind(kdeConnectDevices(0)); }
        function launchKdeConnectSettings() { lastAction = "open"; }
        function refreshKdeConnectDevices() {}
        function runKdeConnectDeviceAction(id, action) { lastAction = action + ":" + id; }
    }

    Item {
        id: host
        width: 300
        height: 240

        Tiles.KdeConnectTile {
            id: tile
            app: app
        }
    }

    TestCase {
        name: "KdeConnectTile"
        when: windowShown

        function init() {
            app.paired = [{ id: "a", name: "Phone" }, { id: "b", name: "Tablet" }];
            app.connected = [{ id: "a", name: "Phone" }];
            app.lastAction = "";
            host.width = 300;
            host.height = 240;
        }

        function test_states_and_empty() {
            compare(tile.totalDevices, 2);
            compare(tile.reachableDevices, 1);
            app.paired = [];
            compare(tile.hasDevices, false);
        }

        function test_overflow_keeps_one_row_and_reports_more() {
            app.paired = [1, 2, 3, 4, 5, 6].map(i => ({ id: "d" + i, name: "Device " + i }));
            host.height = 150;
            verify(tile.visibleDeviceCount < tile.totalDevices);
            verify(tile.visibleDeviceCount >= 1);
        }

        function test_icon_only_when_small() {
            host.width = 80;
            host.height = 80;
            compare(tile.iconOnly, true);
        }

        function test_tile_click_opens_app() {
            mouseClick(tile, 5, 5);
            compare(app.lastAction, "open");
        }
    }
}
