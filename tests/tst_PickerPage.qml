import QtQuick
import QtTest
import "../contents/ui/shell/editor" as Editor

// D-64: the picker page of an enum field. A click or Enter on a usable chip picks it; a chip the machine lacks is dimmed,
// cannot be clicked, and keyboard focus skips it. Arrows move between chips in the two columns.
Item {
    id: testRoot

    width: 300
    height: 300

    property var got: []

    Editor.PickerPage {
        id: page

        width: 300
        height: 200
        options: [
            { "value": "a", "label": "A" },
            { "value": "b", "label": "B", "enabled": false },
            { "value": "c", "label": "C" },
            { "value": "d", "label": "D" },
            { "value": "e", "label": "E", "enabled": false }
        ]
        value: "c"
        missingText: "Not found"
        onPicked: v => testRoot.got.push(v)
    }

    TestCase {
        name: "PickerPage"
        when: windowShown

        function init() {
            testRoot.got = [];
            page.value = "c";
            page.focusStart();
        }

        // Chip i's centre: two columns, rows of chipH + gap.
        function chipX(i) {
            return (i % 2) * (page.chipW + 8) + page.chipW / 2;
        }

        function chipY(i) {
            return Math.floor(i / 2) * 48 + 20;
        }

        function test_opens_on_the_chosen_option() {
            compare(page.current, 2);
            page.value = "zzz";
            page.focusStart();
            compare(page.current, 0);
        }

        function test_a_click_picks_a_usable_option() {
            mouseClick(page, chipX(3), chipY(3));
            compare(testRoot.got, ["d"]);
        }

        function test_a_disabled_option_cannot_be_clicked() {
            mouseClick(page, chipX(1), chipY(1));
            mouseClick(page, chipX(4), chipY(4));
            compare(testRoot.got, []);
        }

        function test_arrows_skip_disabled_chips_and_enter_picks() {
            page.current = 0;
            keyClick(Qt.Key_Right);
            compare(page.current, 2, "B is disabled, so the focus jumps over it");
            keyClick(Qt.Key_Right);
            compare(page.current, 3);
            keyClick(Qt.Key_Left);
            compare(page.current, 2);
            keyClick(Qt.Key_Left);
            compare(page.current, 0, "and back over it");
            keyClick(Qt.Key_Down);
            compare(page.current, 2);
            keyClick(Qt.Key_Down);
            compare(page.current, 2, "E is disabled and nothing lies below");
            keyClick(Qt.Key_Up);
            compare(page.current, 0);
            keyClick(Qt.Key_Return);
            compare(testRoot.got, ["a"]);
        }

        function test_keyboard_cannot_pick_a_disabled_option() {
            page.current = 1;
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Space);
            compare(testRoot.got, []);
            verify(!page.usable(1));
            verify(!page.usable(4));
            verify(!page.usable(9));
        }
    }
}
