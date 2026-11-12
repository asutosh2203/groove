pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.taskmanager as TaskManager
import "../logic/AppMatch.js" as AppMatch

// The single app launcher: desktop entries (the calendar, the notification fallback), the settings pages the Control
// Center opens, and the calendar/forecast clicks. Commands run through the injected CommandRunner.
Item {
    id: launcher

    required property var runner
    // Plasmoid.configuration.calendarApp; empty means "use the system default".
    property string configuredCalendarApp: ""
    property bool forecastAvailable: false
    property string forecastUrl: ""
    property string discoveredCalendarApp: ""
    // desktop id -> { display, path } from Plasma's "apps" engine. A missing key means "not looked up yet", which counts
    // as not openable until the answer arrives a moment later.
    property var desktopEntryInfo: ({})
    property var desktopEntrySources: ({})
    // The app is picked by an id that came from another app, so only plain desktop ids launch. One launch at a time.
    property string pendingLaunchEntry: ""
    property int launchLookups: 0
    readonly property string calendarDiscoveryCommand: 'echo "DI_CAL $(xdg-mime query default text/calendar 2>/dev/null)"'

    // The widget's settings page is opened by the owner of the Plasmoid.
    signal configureRequested()

    function discoverCalendarApp() {
        runner.run(calendarDiscoveryCommand, applyCalendarDiscovery);
    }

    function applyCalendarDiscovery(stdout) {
        const text = String(stdout).trim();
        if (text.indexOf("DI_CAL") === 0)
            discoveredCalendarApp = text.substring(6).trim();
    }

    function calendarAppId() {
        const configured = String(configuredCalendarApp || "").trim();
        return (configured.length > 0 ? configured : discoveredCalendarApp).replace(/\.desktop$/, "");
    }

    function lookupDesktopEntry(entry) {
        const names = entry.endsWith(".desktop") ? [entry + ".desktop", entry] : [entry + ".desktop"];
        for (const name of names) {
            if (desktopEntrySources[name] === undefined) {
                desktopEntrySources[name] = entry;
                appsSource.connectSource(name);
            }
        }
    }

    // Ids come from other apps, so only plain desktop ids pass. An already-running app is activated through Plasma's
    // task manager model (plasmashell is KWin's trusted shell, so this un-minimizes and raises even tray apps like
    // Telegram, which ignore a relaunch); otherwise the desktop file is launched.
    function launch(id) {
        const entry = String(id || "").trim();
        if (!/^[A-Za-z0-9._-]+$/.test(entry) || pendingLaunchEntry.length > 0)
            return ;

        pendingLaunchEntry = entry;
        launchLookups = 0;
        tasksLoader.active = true;
        taskLookupTimer.restart();
    }

    // The model fills in asynchronously, so an empty one is retried a few times before concluding "not running".
    function finishLaunch() {
        const entry = pendingLaunchEntry;
        const model = tasksLoader.item as TaskManager.TasksModel;
        if (model && model.rowCount() === 0 && ++launchLookups < 5) {
            taskLookupTimer.restart();
            return ;
        }

        let activated = false;
        if (model) {
            const tasks = [];
            for (let i = 0; i < model.rowCount(); ++i) {
                const idx = model.index(i, 0);
                tasks.push({
                    "appId": model.data(idx, TaskManager.AbstractTasksModel.AppId),
                    "launcherUrl": model.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon),
                    "isWindow": model.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                });
            }
            const hit = AppMatch.findTask(entry, tasks);
            if (hit >= 0) {
                model.requestActivate(model.index(hit, 0));
                activated = true;
            }
        }
        pendingLaunchEntry = "";
        tasksLoader.active = false;
        if (!activated)
            runDesktopEntry(entry);
    }

    // `kioclient exec` on the desktop file, falling back to gtk-launch. The id is tried as "<id>.desktop" and
    // as-is (org.telegram.desktop is the file org.telegram.desktop.desktop); plasmashell has no XDG_DATA_DIRS,
    // so the Flatpak exports are listed explicitly.
    function runDesktopEntry(entry) {
        runner.run("setsid sh -c 'f=; IFS=:; "
            + "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share}; do "
            + "for n in \"" + entry + ".desktop\" \"" + entry + "\"; do "
            + "[ -f \"$d/applications/$n\" ] && f=\"$d/applications/$n\" && break 2; done; done; "
            + "if [ -n \"$f\" ]; then kioclient exec \"$f\"; else gtk-launch " + entry + "; fi' >/dev/null 2>&1 &");
    }

    function openCalendar() {
        launch(calendarAppId());
    }

    function openForecast() {
        if (forecastAvailable)
            Qt.openUrlExternally(forecastUrl);
        else
            configureRequested();
    }

    function launchPavucontrol() {
        runner.run("pavucontrol");
    }

    function launchNetworkSettings() {
        runner.run("kcmshell6 kcm_networkmanagement");
    }

    function launchBluetoothSettings() {
        runner.run("kcmshell6 kcm_bluetooth");
    }

    function launchDisplaySettings() {
        runner.run("kcmshell6 kcm_kscreen");
    }

    function launchNotificationSettings() {
        runner.run("kcmshell6 kcm_notifications");
    }

    function launchKdeConnectSettings() {
        runner.run("kdeconnect-app");
    }

    function launchAppearanceSettings() {
        runner.run("kcmshell6 kcm_lookandfeel");
    }

    function launchSystemSettings() {
        runner.run("systemsettings");
    }

    function launchPowerSettings() {
        runner.run("kcmshell6 kcm_powerdevilprofilesconfig");
    }

    function launchBluetoothDiscovery() {
        runner.run("kcmshell6 kcm_bluetooth");
    }

    // One-shot lookups of desktop entries (is the entry a launchable app or a NoDisplay background service?).
    Plasma5Support.DataSource {
        id: appsSource

        engine: "apps"
        onNewData: (sourceName, data) => {
            const entry = launcher.desktopEntrySources[sourceName];
            if (entry !== undefined) {
                const info = Object.assign({}, launcher.desktopEntryInfo);
                info[entry] = { "display": data.display === true, "path": String(data.entryPath || "") };
                launcher.desktopEntryInfo = info;
            }
            disconnectSource(sourceName);
        }
    }

    // Created only while a launch looks for an existing window, so nothing watches windows while idle.
    Loader {
        id: tasksLoader

        active: false
        sourceComponent: TaskManager.TasksModel {
            filterByVirtualDesktop: false
            filterByScreen: false
            filterByActivity: false
            groupMode: TaskManager.TasksModel.GroupDisabled
        }
    }

    Timer {
        id: taskLookupTimer

        interval: 150
        onTriggered: launcher.finishLaunch()
    }
}
