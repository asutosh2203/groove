import QtQuick
import QtTest
import "../contents/ui/services"

TestCase {
    id: tc

    name: "AppLauncher"
    when: windowShown

    QtObject {
        id: fakeRunner

        property var calls: []
        function run(command, handler) {
            calls.push(command);
        }
    }

    AppLauncher {
        id: launcher

        runner: fakeRunner
    }

    SignalSpy {
        id: configureSpy

        target: launcher
        signalName: "configureRequested"
    }

    function init() {
        fakeRunner.calls = [];
        launcher.configuredCalendarApp = "";
        launcher.discoveredCalendarApp = "";
        launcher.forecastAvailable = false;
        launcher.pendingLaunchEntry = "";
        configureSpy.clear();
    }

    function test_settings_launchers_run_their_exact_commands() {
        launcher.launchPavucontrol();
        launcher.launchNetworkSettings();
        launcher.launchBluetoothSettings();
        launcher.launchDisplaySettings();
        launcher.launchNotificationSettings();
        launcher.launchKdeConnectSettings();
        launcher.launchAppearanceSettings();
        launcher.launchSystemSettings();
        launcher.launchPowerSettings();
        launcher.launchBluetoothDiscovery();
        compare(fakeRunner.calls, [
            "pavucontrol",
            "kcmshell6 kcm_networkmanagement",
            "kcmshell6 kcm_bluetooth",
            "kcmshell6 kcm_kscreen",
            "kcmshell6 kcm_notifications",
            "kdeconnect-app",
            "kcmshell6 kcm_lookandfeel",
            "systemsettings",
            "kcmshell6 kcm_powerdevilprofilesconfig",
            "kcmshell6 kcm_bluetooth"
        ]);
    }

    function test_calendar_app_prefers_the_configured_one_and_strips_desktop() {
        compare(launcher.calendarAppId(), "");
        launcher.discoveredCalendarApp = "org.kde.korganizer.desktop";
        compare(launcher.calendarAppId(), "org.kde.korganizer");
        launcher.configuredCalendarApp = "  org.gnome.Calendar.desktop ";
        compare(launcher.calendarAppId(), "org.gnome.Calendar");
    }

    function test_calendar_discovery_parses_only_its_own_output() {
        launcher.applyCalendarDiscovery("something else\n");
        compare(launcher.discoveredCalendarApp, "");
        launcher.applyCalendarDiscovery("DI_CAL org.kde.korganizer.desktop\n");
        compare(launcher.discoveredCalendarApp, "org.kde.korganizer.desktop");
        launcher.applyCalendarDiscovery("DI_CAL \n");
        compare(launcher.discoveredCalendarApp, "");
        launcher.discoverCalendarApp();
        compare(fakeRunner.calls, ['echo "DI_CAL $(xdg-mime query default text/calendar 2>/dev/null)"']);
    }

    function test_only_plain_desktop_ids_launch() {
        launcher.launch("");
        launcher.launch("a b");
        launcher.launch("x;rm -rf");
        launcher.launch("$(id)");
        wait(300);
        compare(fakeRunner.calls.length, 0);
        compare(launcher.pendingLaunchEntry, "");
    }

    function test_a_missing_window_falls_back_to_the_desktop_file() {
        launcher.launch("zz.test.app");
        compare(launcher.pendingLaunchEntry, "zz.test.app");
        launcher.launch("other.app"); // one launch at a time
        compare(launcher.pendingLaunchEntry, "zz.test.app");
        tryCompare(fakeRunner.calls, "length", 1, 4000);
        compare(launcher.pendingLaunchEntry, "");
        compare(fakeRunner.calls[0], "setsid sh -c 'f=; IFS=:; "
            + "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share}; do "
            + "for n in \"zz.test.app.desktop\" \"zz.test.app\"; do "
            + "[ -f \"$d/applications/$n\" ] && f=\"$d/applications/$n\" && break 2; done; done; "
            + "if [ -n \"$f\" ]; then kioclient exec \"$f\"; else gtk-launch zz.test.app; fi' >/dev/null 2>&1 &");
    }

    function test_forecast_without_a_location_asks_for_the_settings_page() {
        launcher.openForecast();
        compare(configureSpy.count, 1);
    }
}
