import QtQuick
import QtTest
import "../contents/ui/shell/editor" as Editor

// D-56: the generated form's controls report what the user picks: segmented (the size control), switch, number stepper.
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
        text: value + " min"
        onPicked: v => testRoot.got.push(v)
    }

    TestCase {
        name: "EditControls"
        when: windowShown

        function init() {
            testRoot.got = [];
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

        function test_holding_a_button_repeats_until_released() {
            num.value = 0;
            num.max = 100;
            mousePress(num, num.width - 5, num.height / 2);
            wait(1000);
            mouseRelease(num, num.width - 5, num.height / 2);
            verify(testRoot.got.length > 3);
            const n = testRoot.got.length;
            wait(400);
            compare(testRoot.got.length, n);
            num.value = 9;
            num.max = 10;
        }
    }
}
