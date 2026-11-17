import QtQuick
import QtQuick.Layouts
import QtTest
import "../contents/ui/shell/editor" as Editor

// The location field's results are picked with a click, also when the list hangs below the field's own bounds (inside a
// form row, as in the settings form), and pointer movement over a row is seen.
Item {
    id: testRoot

    width: 500
    height: 400

    property var picks: []

    QtObject {
        id: fakeApp

        property var strings: ({ "editLocationPlaceholder": "Search", "editSearching": "", "editSearchShort": "", "editSearchFailed": "", "editSearchNone": "" })
        property var editor: ({ "fieldFocused": false })
    }

    Item {
        id: rootItem

        focus: true
    }

    // The same nesting as SettingsForm: a layout, a row, a holder that is only as big as its content.
    ColumnLayout {
        x: 20
        y: 20
        width: 400

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            Item {
                id: holder

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: childrenRect.width
                height: childrenRect.height

                Loader {
                    id: loader

                    sourceComponent: Editor.LocationField {
                        width: 200
                        app: fakeApp
                        focusRoot: rootItem
                        onPicked: location => testRoot.picks.push(location)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
        }
    }

    TestCase {
        name: "LocationField"
        when: windowShown

        function test_click_on_a_result_picks_it() {
            const field = loader.item;
            verify(field);
            mouseClick(field, 10, 10);
            tryVerify(() => field.editing);
            field.search.results = [{ "text": "Lisbon, Portugal", "name": "Lisbon", "lat": 38.7, "lon": -9.1 }, { "text": "Lisbon, Ohio", "name": "Lisbon", "lat": 40.7, "lon": -80.7 }];
            wait(100);
            const p = field.mapToItem(testRoot, 20, 60);
            compare(testRoot.childAt(p.x, p.y) !== null, true);
            mouseMove(testRoot, p.x, p.y);
            wait(50);
            mouseClick(testRoot, p.x, p.y);
            tryCompare(testRoot.picks, "length", 1);
            compare(testRoot.picks[0].name, "Lisbon");
        }
    }
}
