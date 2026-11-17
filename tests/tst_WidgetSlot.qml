import QtQuick
import QtTest
import "../contents/ui/shell" as Shell
import "../contents/ui/logic/WidgetRegistry.js" as Registry
import "../contents/ui/widgets/Manifests.js" as Manifests

// D-54: the widget host draws the standard states, holds the declared subscriptions for the slot's life and runs the click.
Item {
    id: testRoot

    width: 400
    height: 300

    property int clockSubs: 0
    property int clockUnsubs: 0
    property int weatherSubs: 0
    property int weatherUnsubs: 0
    property var lastAction: null
    property string zoneState: "ready"

    QtObject {
        id: weatherService

        property bool configured: true
        property bool hasData: true
        property real temperatureC: 20
        property int weatherCode: 3
        property bool isDay: true
        property string locationName: "Testville"
        property var forecast: null
        property double updatedMs: Date.now() - 3 * 3600000
        property bool busy: false
        property bool failing: true
        property bool fahrenheit: false
        property string forecastUrl: "https://example.org/forecast"
        function subscribe() { testRoot.weatherSubs++; }
        function unsubscribe() { testRoot.weatherUnsubs++; }
    }

    QtObject {
        id: clockService

        property double nowMs: Date.UTC(2026, 10, 17, 20, 0)
        property real localOffset: 19800
        property string localZone: "Asia/Kolkata"
        function zoneState(zone) { return testRoot.zoneState; }
        function offsetOf(zone) { return zone === "Asia/Tokyo" ? 32400 : 19800; }
        function subscribe(list) { testRoot.clockSubs++; }
        function unsubscribe(list) { testRoot.clockUnsubs++; }
    }

    QtObject {
        id: fakeApp

        readonly property bool reduceMotion: true
        readonly property bool use24Hour: true
        readonly property var clock: clockService
        readonly property var weatherHub: QtObject {
            function serviceFor(location) { return weatherService; }
        }
        readonly property var widgets: QtObject {
            readonly property var registry: Registry.build(Manifests.list)
        }
        readonly property var strings: QtObject {
            readonly property string widgetUnavailable: "Widget unavailable"
            readonly property string widgetError: "Couldn't load"
            readonly property string widgetSetLocation: "Set a location"
            readonly property string widgetUnknownZone: "Unknown time zone"
            readonly property string today: "Today"
            function updatedAgo(unit, n) { return "updated " + n + " " + unit; }
            function dayRelation(r) { return "rel"; }
            function condition(key) { return key; }
        }
        function runWidgetAction(action) { testRoot.lastAction = action; }
    }

    Component {
        id: slotComponent

        Shell.WidgetSlot {
            width: 154
            height: 96
            app: fakeApp
        }
    }

    TestCase {
        name: "WidgetSlot"
        when: windowShown

        function make(placement) {
            const slot = createTemporaryObject(slotComponent, testRoot, { "placement": placement });
            verify(slot !== null);
            return slot;
        }

        // Every Text under an item, so a test can look for a string without naming the label.
        function texts(item) {
            let out = [];
            if (item.text !== undefined && item.visible)
                out.push(String(item.text));
            for (let i = 0; i < item.children.length; ++i)
                out = out.concat(texts(item.children[i]));
            return out;
        }

        function init() {
            testRoot.clockSubs = 0;
            testRoot.clockUnsubs = 0;
            testRoot.weatherSubs = 0;
            testRoot.weatherUnsubs = 0;
            testRoot.lastAction = null;
            testRoot.zoneState = "ready";
        }

        function test_a_missing_widget_keeps_its_slot() {
            const slot = make({ "widget": "gone", "span": "1x1", "settings": { "x": 1 }, "settingsVersion": 3 });
            compare(slot.available, false);
            verify(texts(slot).indexOf("Widget unavailable") >= 0);
            compare(slot.clickable, false);
            compare(testRoot.clockSubs, 0);
        }

        function test_clock_ready_shows_time_and_clicks_through_the_host() {
            const slot = make({ "widget": "clock", "span": "1x1", "settings": { "timezone": "Asia/Tokyo" }, "settingsVersion": 1 });
            compare(slot.viewState, "ready");
            const t = texts(slot);
            verify(t.indexOf("05:00") >= 0, t.join("|"));
            verify(t.indexOf("Tokyo") >= 0, t.join("|"));
            compare(slot.clickable, true);
            mouseClick(slot, 10, 10);
            compare(testRoot.lastAction.type, "calendar");
        }

        function test_loading_draws_a_skeleton_and_no_content() {
            testRoot.zoneState = "loading";
            const slot = make({ "widget": "clock", "span": "1x1", "settings": {}, "settingsVersion": 1 });
            compare(slot.viewState, "loading");
            compare(slot.showsContent, false);
            compare(slot.clickable, false);
        }

        function test_an_unknown_zone_shows_the_widgets_message() {
            testRoot.zoneState = "error";
            const slot = make({ "widget": "clock", "span": "1x1", "settings": { "timezone": "Nowhere/Land" }, "settingsVersion": 1 });
            compare(slot.viewState, "error");
            verify(texts(slot).indexOf("Unknown time zone") >= 0);
        }

        function test_stale_keeps_the_content_and_adds_the_age() {
            const slot = make({ "widget": "weather", "span": "1x1", "settings": {}, "settingsVersion": 1 });
            compare(slot.viewState, "stale");
            const t = texts(slot);
            verify(t.indexOf("updated 3 hour") >= 0, t.join("|"));
            verify(t.indexOf("Testville") >= 0, t.join("|"));
            compare(slot.clickable, true);
        }

        function test_needs_setup_says_so_and_is_not_clickable() {
            weatherService.configured = false;
            const slot = make({ "widget": "weather", "span": "1x1", "settings": {}, "settingsVersion": 1 });
            compare(slot.viewState, "needsSetup");
            verify(texts(slot).indexOf("Set a location") >= 0);
            compare(slot.clickable, false);
            weatherService.configured = true;
        }

        function test_subscriptions_live_exactly_as_long_as_the_slot() {
            const slot = make({ "widget": "weather", "span": "1x1", "settings": {}, "settingsVersion": 1 });
            compare(testRoot.weatherSubs, 1);
            compare(testRoot.clockSubs, 0);
            slot.destroy();
            wait(50);
            compare(testRoot.weatherUnsubs, 1);
        }

        function test_only_declared_services_are_taken() {
            const slot = make({ "widget": "clock", "span": "1x1", "settings": {}, "settingsVersion": 1 });
            compare(testRoot.clockSubs, 1);
            compare(testRoot.weatherSubs, 0);
            slot.destroy();
            wait(50);
            compare(testRoot.clockUnsubs, 1);
        }
    }
}
