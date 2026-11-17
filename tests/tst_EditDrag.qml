import QtQuick
import QtTest

// The editor's tile and catalogue row: a click opens, a drag past the threshold reports begin, moves and end (and no click),
// (the centroid resets to 0,0 on release, so only an active drag moves) using the same MouseArea + DragHandler structure as EditGrid and EditCatalogue.
Item {
    id: testRoot

    width: 400
    height: 300

    property int clicks: 0
    property int begins: 0
    property int ends: 0
    property point last: Qt.point(0, 0)

    function dragBegin() { testRoot.begins++; }
    function dragEnd() { testRoot.ends++; }
    function dragMove(p) { testRoot.last = testRoot.mapFromItem(null, p.x, p.y); }

    Item {
        id: tile

        x: 20
        y: 20
        width: 100
        height: 60

        MouseArea {
            anchors.fill: parent
            onClicked: testRoot.clicks++

            DragHandler {
                target: null
                onActiveChanged: active ? testRoot.dragBegin() : testRoot.dragEnd()
                onCentroidChanged: if (active) testRoot.dragMove(centroid.scenePosition)
            }
        }
    }

    TestCase {
        name: "EditDrag"
        when: windowShown

        function init() {
            testRoot.clicks = 0;
            testRoot.begins = 0;
            testRoot.ends = 0;
        }

        function test_click_is_a_click() {
            mouseClick(tile, 10, 10);
            compare(testRoot.clicks, 1);
            compare(testRoot.begins, 0);
        }

        function test_drag_reports_and_is_not_a_click() {
            mousePress(tile, 10, 10);
            mouseMove(tile, 30, 20);
            mouseMove(tile, 120, 100);
            mouseMove(tile, 200, 150);
            mouseRelease(tile, 200, 150);
            compare(testRoot.begins, 1);
            compare(testRoot.ends, 1);
            compare(testRoot.clicks, 0);
            verify(Math.abs(testRoot.last.x - 220) < 3);
            verify(Math.abs(testRoot.last.y - 170) < 3);
        }
    }
}
