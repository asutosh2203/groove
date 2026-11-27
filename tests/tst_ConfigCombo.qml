import QtQuick
import QtTest
import "../contents/ui" as UI

Item {
    id: testRoot
    width: 300
    height: 100

    // The config dialog hands the page its saved value at creation, so the combos start with it already set.
    property string saved: "notch"

    UI.ConfigCombo {
        id: shape
        rows: [{ "text": "Dynamic Pill", "value": "pill" }, { "text": "Dynamic Notch", "value": "notch" }]
        selected: testRoot.saved
    }

    UI.ConfigCombo {
        id: unit
        y: 40
        rows: [{ "text": "Celsius", "value": "celsius" }, { "text": "Fahrenheit", "value": "fahrenheit" }]
        selected: "fahrenheit"
    }

    TestCase {
        name: "ConfigCombo"
        when: windowShown

        function test_a_saved_second_row_is_shown_at_creation() {
            compare(shape.currentValue, "notch");
            compare(shape.displayText, "Dynamic Notch");
            compare(unit.currentValue, "fahrenheit");
        }

        function test_it_follows_the_saved_value() {
            testRoot.saved = "pill";
            compare(shape.currentValue, "pill");
            testRoot.saved = "notch";
            compare(shape.currentValue, "notch");
        }

        function test_an_unknown_value_falls_back_to_the_first_row() {
            testRoot.saved = "";
            compare(shape.currentValue, "pill");
            testRoot.saved = "notch";
        }
    }
}
