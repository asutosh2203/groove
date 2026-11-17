import QtQuick
import QtTest
import "../contents/ui/shell/editor" as Editor

// D-56: the time zone field searches Plasma's zone data; without it, it is a plain id entry validated through Clock.
Item {
    id: testRoot

    width: 500
    height: 300

    property var picks: []

    QtObject {
        id: fakeApp

        property var strings: ({ "editLocalTime": "Local time", "editZonePlaceholder": "Search", "editZoneIdPlaceholder": "Id", "editZoneUnknown": "Unknown time zone" })
        property var editor: ({ "fieldFocused": false })
    }

    Item {
        id: rootItem

        focus: true
    }

    Editor.TimezoneField {
        id: searchField

        x: 20
        y: 20
        width: 200
        app: fakeApp
        focusRoot: rootItem
        value: "Europe/Lisbon"
        onPicked: zone => testRoot.picks.push(zone)
    }

    Editor.TimezoneField {
        id: plainField

        x: 20
        y: 120
        width: 200
        app: fakeApp
        focusRoot: rootItem
        finderSource: "NoSuchFile.qml"
        value: "local"
        onPicked: zone => testRoot.picks.push(zone)
    }

    TestCase {
        name: "TimezoneField"
        when: windowShown

        function init() {
            testRoot.picks = [];
        }

        function test_the_zone_data_is_used_when_it_loads() {
            tryVerify(() => searchField.searching);
            compare(searchField.shownName.length > 0, true);
            verify(searchField.shownName !== "Local time");
            mouseClick(searchField, 10, 10);
            tryVerify(() => searchField.editing);
            wait(50);
            keyClick(Qt.Key_L);
            keyClick(Qt.Key_I);
            keyClick(Qt.Key_S);
            keyClick(Qt.Key_B);
            wait(100);
            compare(searchField.finder.query, "lisb");
            verify(searchField.finder.zones.rowCount() > 0);
        }

        function test_without_the_zone_data_an_unknown_id_is_refused_and_a_real_one_taken() {
            verify(!plainField.searching);
            compare(plainField.shownName, "Local time");
            mouseClick(plainField, 10, 10);
            tryVerify(() => plainField.editing);
            keyClick(Qt.Key_A, Qt.ControlModifier);
            for (const c of "Not/AZone")
                keyClick(c);
            keyClick(Qt.Key_Return);
            verify(plainField.invalid);
            compare(testRoot.picks.length, 0);
            keyClick(Qt.Key_A, Qt.ControlModifier);
            for (const c of "Europe/Lisbon")
                keyClick(c);
            keyClick(Qt.Key_Return);
            tryCompare(testRoot.picks, "length", 1);
            compare(testRoot.picks[0], "Europe/Lisbon");
        }
    }
}
