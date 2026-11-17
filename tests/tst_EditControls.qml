import QtQuick
import QtTest
import "../contents/ui/shell/editor" as Editor

// D-56: the generated form's controls report what the user picks: segmented, switch, number stepper and slider, dropdown.
Item {
    id: testRoot

    width: 400
    height: 400

    property var got: []

    Editor.Segmented {
        id: seg

        x: 10
        y: 10
        options: [{ "value": "a", "label": "A" }, { "value": "b", "label": "B", "enabled": false }, { "value": "c", "label": "C" }]
        value: "a"
        onPicked: v => testRoot.got.push(v)
    }

    Editor.SwitchControl {
        id: sw

        x: 10
        y: 60
        onToggled: v => testRoot.got.push(v)
    }

    Editor.NumberEntry {
        id: num

        x: 10
        y: 100
        value: 9
        min: 0
        max: 10
        step: 2
        onPicked: v => testRoot.got.push(v)
    }

    Editor.DropdownField {
        id: drop

        x: 10
        y: 160
        options: [{ "value": "x", "label": "X" }, { "value": "y", "label": "Y" }]
        value: "x"
        onPicked: v => testRoot.got.push(v)
    }

    TestCase {
        name: "EditControls"
        when: windowShown

        function init() {
            testRoot.got = [];
            drop.open = false;
        }

        function test_segmented_picks_enabled_options_only() {
            mouseClick(seg, seg.width - 10, seg.height / 2);
            compare(testRoot.got, ["c"]);
            mouseClick(seg, seg.width / 2, seg.height / 2);
            compare(testRoot.got, ["c"]);
        }

        function test_switch_reports_the_new_state() {
            mouseClick(sw, 5, 5);
            compare(testRoot.got, [true]);
        }

        function test_stepper_steps_and_stays_within_the_range() {
            mouseClick(num, num.width - 5, num.height / 2);
            compare(testRoot.got, [10]);
            mouseClick(num, 5, num.height / 2);
            compare(testRoot.got, [10, 7]);
        }

        function test_dropdown_opens_and_picks() {
            mouseClick(drop, 10, 10);
            verify(drop.open);
            mouseClick(drop, 10, 30 + 40 + 20);
            compare(testRoot.got, ["y"]);
            verify(!drop.open);
        }
    }
}
