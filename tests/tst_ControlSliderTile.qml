import QtQuick
import QtTest
import "../contents/ui/controlcenter"

// The volume tile runs to 150 %: the fill and the readout follow the value through 100-150 and nothing overflows.
TestCase {
    id: tc

    name: "ControlSliderTile"
    when: windowShown
    width: 400
    height: 300

    QtObject {
        id: app

        readonly property var layoutService: QtObject { property bool editMode: false }
    }

    Component {
        id: tileComponent

        ControlSliderTile {
            app: app
            toValue: 150
        }
    }

    function make(w, h, value) {
        const tile = createTemporaryObject(tileComponent, tc, { "width": w, "height": h, "value": value, "valueText": value + "%" });
        verify(tile);
        return tile;
    }

    function test_the_fill_follows_the_value_up_to_150() {
        const values = [0, 100, 125, 150];
        for (let i = 0; i < values.length; ++i) {
            const tile = make(78, 245, values[i]);
            compare(tile.safeValue, values[i]);
            fuzzyCompare(tile.ratio, values[i] / 150, 0.0001);
            verify(tile.fillExtent <= tile.height + 0.5, "the fill stays inside the tile at " + values[i]);
        }
    }

    function test_a_value_above_the_range_is_clamped_to_150_not_beyond() {
        const tile = make(300, 80, 400);
        compare(tile.safeValue, 150);
        compare(tile.ratio, 1);
        verify(tile.fillExtent <= tile.width + 0.5);
    }

    function test_keyboard_steps_reach_150_and_stop_there() {
        const tile = make(300, 80, 145);
        const sent = [];
        tile.moved.connect(v => sent.push(v));
        tile.adjustBy(tile.keyboardStep);
        tile.adjustBy(tile.keyboardStep);
        verify(sent.length > 0);
        compare(Math.max.apply(null, sent), 150);
        verify(sent.every(v => v <= 150 && v >= 0));
    }
}
