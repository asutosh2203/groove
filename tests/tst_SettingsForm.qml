import QtQuick
import QtTest
import "../contents/ui/shell/editor" as Editor
import "../contents/ui/logic/WidgetRegistry.js" as Registry
import "../contents/ui/widgets/Manifests.js" as Manifests

// The form's model (from the placement) and its layout plan (from the deck) update one after the other, so for a moment the
// plan can name a field the new widget does not have. The rows must tolerate that instead of throwing.
Item {
    id: testRoot

    width: 700
    height: 500

    readonly property var worldClock: ({ "widget": "world-clock", "span": "2x1", "settings": { "timezone1": "Asia/Tokyo", "timezone2": "Europe/London", "timezone3": "America/New_York", "timeFormat": "auto" } })
    readonly property var clock: ({ "widget": "clock", "span": "1x1", "settings": { "timezone": "local", "label": "", "timeFormat": "auto" } })

    QtObject {
        id: clockService

        property double nowMs: Date.UTC(2026, 10, 17, 20, 0)
        property real localOffset: 19800
        property string localZone: "Asia/Kolkata"
        function zoneState(zone) { return "ready"; }
        function offsetOf(zone) { return 19800; }
        function subscribe(list) {}
        function unsubscribe(list) {}
    }

    QtObject {
        id: fakeEditor

        property var placement: testRoot.worldClock
        readonly property var registry: Registry.build(Manifests.list)
        readonly property var preset: ({ "placements": [testRoot.worldClock] })
        readonly property int formIndex: 0
        readonly property string pageType: "small"
        readonly property string pickerKey: ""
        function setSetting(key, value) {}
        function setSpan(span) {}
        function removePlacement(index) {}
        function openPicker(key) {}
        function pick(value) {}
    }

    QtObject {
        id: fakeApp

        property var formPlan: ({ "cols": [[0, 1], [2, 3]], "stageH": 120, "box": { "w": 200, "h": 100 } })
        readonly property bool reduceMotion: true
        readonly property bool use24Hour: true
        readonly property var editor: fakeEditor
        readonly property var clock: clockService
        readonly property var sysmon: QtObject { readonly property var available: ({}) }
        readonly property var widgets: QtObject { readonly property var registry: fakeEditor.registry }
        readonly property var strings: QtObject {
            readonly property string editSize: "Size"
            readonly property string editRemoveWidget: "Remove widget"
            readonly property string editOptionMissing: "Not found"
            readonly property string widgetUnavailable: "Widget unavailable"
            readonly property string widgetError: "Couldn't load"
            readonly property string widgetUnknownZone: "Unknown time zone"
            function spanName(span) { return span; }
            function spanOnly(span) { return span + " only"; }
            function widgetNote(id, a, b) { return ""; }
        }
        function runWidgetAction(action) {}
    }

    Editor.SettingsForm {
        id: form

        width: 656
        height: 460
        app: fakeApp
        focusRoot: testRoot
    }

    TestCase {
        name: "SettingsForm"
        when: windowShown

        // A placement with fewer fields than the old plan names: the model changes first, the plan follows.
        function test_switching_to_a_widget_with_fewer_fields_does_not_throw() {
            failOnWarning(/SettingsForm\.qml:\d+: TypeError/);
            fakeEditor.placement = testRoot.clock;
            wait(50);
            fakeApp.formPlan = { "cols": [[0, 1], [2]], "stageH": 120, "box": { "w": 100, "h": 100 } };
            wait(50);
            verify(form.model !== null);
            compare(form.model.fields.length, 3);
        }
    }
}
