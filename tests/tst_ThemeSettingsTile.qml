import QtQuick
import QtTest
import "../contents/ui/controlcenter"

// D-40: the former Light/Dark tile is "Theme settings". It opens Global Theme settings through the launcher and closes the
// Control Center, shows the current colour scheme read-only, and never applies a theme. A fake launcher stands in for the
// real one, so nothing is ever run.
TestCase {
    id: tc

    name: "ThemeSettingsTile"
    when: windowShown
    width: 400
    height: 300

    property var calls: []

    QtObject {
        id: fakeApp

        readonly property var layoutService: QtObject {
            property bool editMode: false
            property bool dragActive: false
            property var dragSource: null
            function moduleInfo(id) { return { "id": id, "name": id }; }
            function beginDrag() {}
            function updateDrag() {}
            function endDrag() {}
        }
        readonly property var launcher: QtObject {
            function launchAppearanceSettings() { tc.calls.push("appearance-settings"); }
            function launchSystemSettings() { tc.calls.push("system-settings"); }
        }
        readonly property var system: QtObject { property bool darkColorScheme: true }
        readonly property var strings: QtObject {
            readonly property string themeSettings: "Theme settings"
            readonly property string themeSettingsDetail: "Choose light and dark themes in System Settings"
            readonly property string themeSettingsFooter: "Click to open"
            function colorSchemeName(dark) { return dark ? "Dark" : "Light"; }
        }
        function closeIsland() { tc.calls.push("close"); }
        // Anything that would apply a theme: calling it fails the test.
        function toggleAppearanceMode() { tc.calls.push("APPLIED-A-THEME"); }
    }

    Component {
        id: cardComponent

        ControlCenterModuleCard {
            app: fakeApp
            hostItem: tc.parent
            notificationsSource: QtObject {}
            batterySource: QtObject {}
            connectionsSource: QtObject {}
            screenBrightnessSource: QtObject {}
            keyboardBrightnessSource: QtObject {}
            powerProfilesSource: QtObject {}
            moduleId: "appearanceMode"
            width: 150
            height: 150
        }
    }

    function init() {
        calls = [];
        fakeApp.layoutService.editMode = false;
        fakeApp.system.darkColorScheme = true;
    }

    function test_clicking_opens_theme_settings_then_closes_the_control_center() {
        const card = createTemporaryObject(cardComponent, tc.parent);
        verify(card);
        waitForRendering(card);
        const tile = card.children[0].item;
        mouseClick(card, card.width / 2, card.height / 2);
        compare(calls, ["appearance-settings", "close"]);
    }

    function test_it_shows_the_current_scheme_read_only_and_follows_it() {
        const card = createTemporaryObject(cardComponent, tc.parent);
        waitForRendering(card);
        const tile = card.children[0].item; // the Loader's SimpleModuleTile
        compare(tile.title, "Theme settings");
        compare(tile.subtitle, "Dark");
        fakeApp.system.darkColorScheme = false;
        compare(tile.subtitle, "Light");
        verify(!tile.active); // it is not a switch
        compare(calls.length, 0); // reading the scheme applies nothing
    }

    function test_in_edit_mode_the_tile_is_not_clickable() {
        fakeApp.layoutService.editMode = true;
        const card = createTemporaryObject(cardComponent, tc.parent);
        waitForRendering(card);
        mouseClick(card, card.width / 2, card.height / 2);
        compare(calls.length, 0);
    }

    function test_no_path_applies_a_theme() {
        const card = createTemporaryObject(cardComponent, tc.parent);
        waitForRendering(card);
        mouseClick(card, card.width / 2, card.height / 2);
        verify(calls.indexOf("APPLIED-A-THEME") === -1);
        verify(calls.indexOf("system-settings") === -1); // and it opens the Global Theme page, not the whole System Settings
    }
}
