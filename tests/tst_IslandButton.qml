import QtQuick
import QtTest
import "../contents/ui" as UI

Item {
    id: testRoot
    width: 200
    height: 100

    UI.IslandButton {
        id: first
        x: 10
        y: 10
        iconName: "media-playback-pause"
    }

    UI.IslandButton {
        id: second
        x: 100
        y: 10
        iconName: "media-skip-forward"
    }

    TestCase {
        name: "IslandButton"
        when: windowShown

        function test_click_takes_focus_without_a_ring() {
            mouseClick(first, 10, 10);
            compare(first.activeFocus, true);
            compare(first.showFocusRing, false);
        }

        function test_keyboard_focus_keeps_the_ring() {
            mouseClick(first, 10, 10);
            second.forceActiveFocus(Qt.TabFocusReason);
            compare(first.activeFocus, false);
            first.forceActiveFocus(Qt.TabFocusReason);
            compare(first.activeFocus, true);
            compare(first.showFocusRing, true);
        }

        function test_clicking_still_emits_clicked() {
            let clicks = 0;
            first.clicked.connect(() => clicks++);
            mouseClick(first, 10, 10);
            compare(clicks, 1);
        }
    }
}
