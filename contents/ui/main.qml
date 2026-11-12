pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.plasmoid
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import org.kde.plasma.private.volume
import org.kde.plasma.workspace.keyboardlayout as KeyboardLayout
import org.kde.taskmanager as TaskManager
import "controlcenter"
import "services"
import "logic/ModuleRegistry.js" as ModuleRegistry
import "logic/NetworkState.js" as NetworkState
import "logic/KdeConnectState.js" as KdeConnectState
import "logic/TextUtils.js" as TextUtils
import "logic/Utils.js" as Utils
import "logic/NotificationOpen.js" as NotificationOpen
import "logic/AppMatch.js" as AppMatch
import "logic/FullscreenState.js" as FullscreenState
import "logic/NoticeDuration.js" as NoticeDuration
import "activities" as Activities
import "weather"

PlasmoidItem {
    id: root

    // The widget config as an untyped object: qmllint cannot know the keys of a KConfig map.
    readonly property var settings: Plasmoid.configuration
    readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge].includes(Plasmoid.location)
    readonly property bool verticalPanel: [PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge].includes(Plasmoid.location)
    readonly property bool hasJobs: notificationService.model.activeJobsCount > 0
    readonly property bool mediaActivityEnabled: Plasmoid.configuration.mediaActivityEnabled !== false
    readonly property bool notificationActivityEnabled: Plasmoid.configuration.notificationActivityEnabled !== false
    readonly property bool jobActivityEnabled: Plasmoid.configuration.jobActivityEnabled !== false
    readonly property bool keyboardLayoutActivityEnabled: Plasmoid.configuration.keyboardLayoutActivityEnabled !== false
    readonly property bool notificationImagesEnabled: Plasmoid.configuration.notificationShowImages !== false
    readonly property int notificationBodyCharacters: Math.max(40, Math.min(1000, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationBodyCharacterLimit, 240))))
    readonly property int notificationBodyLines: Math.max(1, Math.min(6, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationBodyLineLimit, 3))))
    readonly property int notificationPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationPopupDurationSeconds, 4)) * 1000))
    readonly property int ongoingPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(Plasmoid.configuration.ongoingPopupDurationSeconds, 3)) * 1000))
    readonly property var keyboardLayoutNames: keyboardLayout.layoutsList.length > keyboardLayout.layout ? keyboardLayout.layoutsList[keyboardLayout.layout] : null
    readonly property string keyboardLayoutShortName: keyboardLayoutNames ? keyboardLayoutNames.shortName || "" : ""
    readonly property string keyboardLayoutDisplayName: keyboardLayoutNames ? keyboardLayoutNames.displayName || keyboardLayoutShortName : keyboardLayoutShortName
    readonly property string keyboardLayoutLongName: keyboardLayoutNames ? keyboardLayoutNames.longName || keyboardLayoutDisplayName : keyboardLayoutDisplayName
    // True while the pointer is over a clickable notice popup (drives the whole-island highlight and the open glyph).
    // The playback position is only drawn by the compact media pill, the expanded media popup and the Control
    // Center's media card, so it is only polled while one of them can be seen.
    readonly property bool mediaPositionVisible: mediaService.hasPlayer && mediaService.isPlaying && !fullscreenCovering && (popupMode === "control" ? dialogVisible : islandOpen ? popupMode === "activity" && popupActivityMode() === "media" : !panelHidden && activityMode() === "media")
    property bool noticeHovered: false
    // True while the pointer is over an activity popup (notice, media, job...), clickable or not. Together with the
    // dialog holding keyboard focus it freezes the popup's timers, which finish with the time left once the pointer
    // or focus is gone.
    property bool popupHovered: false
    readonly property bool holdPopupTimers: dialogVisible && islandOpen && popupMode === "activity" && (popupHovered || dialogActive)
    readonly property bool holdNoticeLifetime: holdPopupTimers && activityPopupMode === "notice"
    readonly property bool hasActivity: keyboardAnnouncementActive || jobActivityEnabled && hasJobs || mediaActivityEnabled && mediaService.shown || notificationService.activityActive
    // Fixed allocation: the panel never resizes for visual transitions. The
    // visible shape is drawn inside whatever slot the panel actually gives us.
    readonly property int islandWidth: 180
    readonly property int islandHeight: 40
    readonly property bool notchShape: Plasmoid.configuration.shellShape === "notch"
    // Notch mode attaches the containing panel to the screen edge (not floating,
    // thickness = shell height) and Pill mode restores the panel's saved settings.
    readonly property int notchPanelThickness: islandHeight
    property int panelSyncPhase: 0 // 0 idle, 1 reading, 2 applying
    property bool panelSyncPending: false
    property int panelSyncAttempts: 0
    property string panelSyncAction: ""
    readonly property real notchShoulder: 8
    readonly property real notchSideMargin: notchShoulder + 4
    readonly property real notchBottomRadius: Math.round(Math.min(realIslandHeight, islandHeight) * 0.35)
    readonly property real compactArtworkSize: Math.max(18, realIslandHeight - 8) - (notchShape ? 2 : 0) // notch: 2px extra bottom inset
    readonly property real realIslandWidth: compactRepresentationItem && compactRepresentationItem.width > 0 ? compactRepresentationItem.width : islandWidth
    readonly property real realIslandHeight: compactRepresentationItem && compactRepresentationItem.height > 0 ? compactRepresentationItem.height : islandHeight
    readonly property int mediaPopupWidth: 340
    readonly property int popupWidth: popupMode === "control" ? (controlLayoutService.editMode ? 620 : 430) : (popupActivityMode() === "media" || popupActivityMode() === "notice" ? mediaPopupWidth : 294)
    readonly property int mediaPopupHeight: 120
    readonly property int popupHeight: popupMode === "control" ? (controlLayoutService.editMode ? 570 : 540) : (popupActivityMode() === "media" || popupActivityMode() === "notice" ? mediaPopupHeight : 104)
    readonly property int popupRadius: popupMode === "control" ? 28 : 26
    readonly property bool islandExpandsUp: Plasmoid.location === PlasmaCore.Types.BottomEdge
    readonly property bool islandExpandsDown: Plasmoid.location === PlasmaCore.Types.TopEdge
    property bool dialogVisible: false
    property bool islandOpen: false
    property bool panelHidden: false
    property bool popupAcceptsFocus: false
    property bool popupMenuOpen: false
    property bool dialogActive: false
    property real popupCollapsedX: (popupWidth - realIslandWidth) / 2
    property real popupCollapsedY: islandExpandsUp ? popupHeight - realIslandHeight : islandExpandsDown ? 0 : (popupHeight - realIslandHeight) / 2
    property string systemUsername: ""
    property string systemHostname: ""
    property string profileImageUrl: ""
    property bool bluetoothPowered: false
    property bool bluetoothAvailable: false
    property string bluetoothAdapterName: ""
    property string bluetoothDevicesText: ""
    property var wifiNetworks: []
    property var networkDevices: []
    property var networkAddresses: []
    readonly property var networkState: NetworkState.summarize(networkDevices, networkAddresses, wifiNetworks, enabledConnections.networkingEnabled, enabledConnections.wirelessEnabled && enabledConnections.wirelessHwEnabled)
    property var kdeConnectPaired: []
    property var kdeConnectConnected: []
    property string popupMode: "control"
    property string activityPopupMode: "auto"
    property int clickButton: Qt.NoButton
    property bool keyboardAnnouncementActive: false
    property int lastActiveJobsCount: 0
    property string screenBrightnessDisplayName: ""
    property int screenBrightnessValue: 0
    property int screenBrightnessMax: 100
    property int screenBrightnessVisualPercent: 0
    property bool screenBrightnessVisualPinned: false
    readonly property string accountIconCommand: "sh -c 'user=$(id -un); path=$(qdbus6 org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName \"$user\" 2>/dev/null); test -n \"$path\" && qdbus6 org.freedesktop.Accounts \"$path\" org.freedesktop.Accounts.User.IconFile 2>/dev/null'"
    readonly property string wifiScanCommand: "env LC_ALL=C nmcli --colors no -t -f IN-USE,SSID,SIGNAL,DEVICE device wifi list --rescan no"
    readonly property string networkStatusCommand: "env LC_ALL=C nmcli --colors no -t -f TYPE,DEVICE,STATE,CONNECTION device status"
    readonly property string networkIpCommand: "env LC_ALL=C nmcli --colors no -t -f GENERAL.DEVICE,IP4.ADDRESS,IP6.ADDRESS device show"


    function screenForPoint(pointX, pointY) {
        const screens = Application.screens;
        let nearestScreen = null;
        let nearestDistance = Number.POSITIVE_INFINITY;
        for (let i = 0; i < screens.length; ++i) {
            const screen = screens[i];
            const left = Utils.finiteNumber(screen.virtualX, 0);
            const top = Utils.finiteNumber(screen.virtualY, 0);
            const width = Math.max(0, Utils.finiteNumber(screen.width, 0));
            const height = Math.max(0, Utils.finiteNumber(screen.height, 0));
            if (width <= 0 || height <= 0)
                continue;

            const right = left + width;
            const bottom = top + height;
            const dx = pointX < left ? left - pointX : pointX > right ? pointX - right : 0;
            const dy = pointY < top ? top - pointY : pointY > bottom ? pointY - bottom : 0;
            const distance = dx * dx + dy * dy;
            if (distance < nearestDistance) {
                nearestScreen = screen;
                nearestDistance = distance;
            }
        }

        return nearestScreen;
    }

    // ---- Containing-panel integration -------------------------------------
    // The panel is found through Plasmoid.containment.id (the scripting panel id)
    // and confirmed by checking that the panel's widget list contains this
    // applet, so a stale or wrong id never touches another panel.
    function panelCommand(applyFloating, applyThickness) {
        const panelId = Math.floor(Number(Plasmoid.containment.id));
        const appletId = Math.floor(Number(Plasmoid.id));
        let apply = "";
        if (applyFloating !== null)
            apply += "p.floating = " + (applyFloating ? "true" : "false") + ";";
        if (applyThickness > 0)
            apply += "p.height = " + Math.floor(applyThickness) + ";";
        const script = "var r = {ok: false}; var p = panelById(" + panelId + "); "
            + "if (p && p.widgetIds.indexOf(" + appletId + ") >= 0) { " + apply
            + " r = {ok: true, id: " + panelId + ", location: p.location, floating: p.floating, height: p.height}; } "
            + "print('DI_PANEL ' + JSON.stringify(r));";
        return "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + Utils.shellQuote(script);
    }

    function onPanelReply(stdout) {
        const text = String(stdout).trim();
        if (text.indexOf("DI_PANEL ") === 0)
            handlePanelReply(text);
    }

    function panelSyncWanted() {
        return notchShape || Plasmoid.configuration.panelOrigPanelId > 0;
    }

    function syncPanel() {
        if (!panelSyncWanted())
            return ;
        if (panelSyncPhase !== 0) {
            panelSyncPending = true;
            return ;
        }
        if (!Plasmoid.containment || !(Plasmoid.containment.id > 0))
            return ;
        panelSyncPhase = 1;
        commands.run(panelCommand(null, 0), onPanelReply);
        panelWatchdog.restart();
    }

    function applyPanel(action, floating, thickness) {
        panelSyncAction = action;
        panelSyncPhase = 2;
        commands.run(panelCommand(floating, thickness), onPanelReply);
        panelWatchdog.restart();
    }

    function clearPanelOriginals() {
        Plasmoid.configuration.panelOrigPanelId = 0;
        Plasmoid.configuration.panelOrigFloating = -1;
        Plasmoid.configuration.panelOrigThickness = 0;
    }

    function decidePanel(state) {
        const cfg = Plasmoid.configuration;
        if (state.location !== "top") {
            console.warn("Dynamic Island: panel is not on the top edge, leaving it untouched");
            return ;
        }
        // Originals only count for the panel they were captured from.
        const stored = cfg.panelOrigPanelId === state.id && cfg.panelOrigFloating >= 0;
        if (notchShape) {
            const attached = !state.floating && state.height === notchPanelThickness;
            if (!stored) {
                // Capture once, before the first change. An already attached panel with
                // no record has an unknown thickness: remember only that it floated.
                cfg.panelOrigPanelId = state.id;
                cfg.panelOrigFloating = attached ? 1 : (state.floating ? 1 : 0);
                cfg.panelOrigThickness = attached ? 0 : state.height;
            }
            if (!attached)
                applyPanel("notch", false, notchPanelThickness);
        } else if (stored) {
            const wantFloating = cfg.panelOrigFloating === 1;
            const wantThickness = cfg.panelOrigThickness;
            if (state.floating === wantFloating && (wantThickness <= 0 || state.height === wantThickness))
                clearPanelOriginals();
            else
                applyPanel("restore", wantFloating, wantThickness);
        }
    }

    function handlePanelReply(out) {
        panelWatchdog.stop();
        let reply = { "ok": false };
        try {
            reply = JSON.parse(out.substring("DI_PANEL ".length));
        } catch (e) {
        }
        const phase = panelSyncPhase;
        panelSyncPhase = 0;
        panelSyncAttempts = 0;
        if (!reply.ok) {
            console.warn("Dynamic Island: could not identify its panel, leaving it untouched");
        } else if (phase === 1) {
            decidePanel(reply);
        } else if (phase === 2) {
            const cfg = Plasmoid.configuration;
            if (panelSyncAction === "restore") {
                if (reply.floating === (cfg.panelOrigFloating === 1) && (cfg.panelOrigThickness <= 0 || reply.height === cfg.panelOrigThickness))
                    clearPanelOriginals();
                else
                    console.warn("Dynamic Island: panel restore did not fully apply; original settings kept for a retry");
            } else if (reply.floating || reply.height !== notchPanelThickness) {
                console.warn("Dynamic Island: panel did not accept the notch settings");
            }
        }
        if (panelSyncPhase === 0 && panelSyncPending) {
            panelSyncPending = false;
            Qt.callLater(syncPanel);
        }
    }

    function positionIslandDialog() {
        const item = root.compactRepresentationItem || root;
        if (!item || !item.mapToGlobal)
            return ;

        const pos = item.mapToGlobal(0, 0);
        const collapsedX = pos.x + item.width / 2 - realIslandWidth / 2;
        const collapsedY = pos.y + item.height / 2 - realIslandHeight / 2;
        let dialogX = collapsedX - (popupWidth - realIslandWidth) / 2;
        let dialogY = collapsedY - (popupHeight - realIslandHeight) / 2;
        if (Plasmoid.location === PlasmaCore.Types.BottomEdge)
            dialogY = collapsedY - (popupHeight - realIslandHeight);
        else if (Plasmoid.location === PlasmaCore.Types.TopEdge)
            dialogY = collapsedY;

        const popupScreen = screenForPoint(collapsedX + realIslandWidth / 2, collapsedY + realIslandHeight / 2);
        if (popupScreen) {
            dialogX = Utils.clampNumber(dialogX, popupScreen.virtualX, popupScreen.virtualX + popupScreen.width - popupWidth);
            dialogY = Utils.clampNumber(dialogY, popupScreen.virtualY, popupScreen.virtualY + popupScreen.height - popupHeight);
        }

        islandDialog.x = Math.round(dialogX);
        islandDialog.y = Math.round(dialogY);
        popupCollapsedX = collapsedX - islandDialog.x;
        popupCollapsedY = collapsedY - islandDialog.y;
    }

    function openIsland(mode, autoClose) {
        const wasOpen = dialogVisible && islandOpen;
        closeDialogTimer.stop();
        openHandoffTimer.stop();
        activityPopupTimer.stop();
        popupMode = mode;
        if (!wasOpen) {
            popupAcceptsFocus = false;
            popupMenuOpen = false;
            dialogActive = false;
        }
        expanded = false;
        dialogVisible = true;
        Qt.callLater(positionIslandDialog);
        if (wasOpen) {
            panelHidden = true;
            islandOpen = true;
        } else {
            islandOpen = false;
            openHandoffTimer.restart();
        }
        if (autoClose)
            activityPopupTimer.restart();

    }

    function closeIsland() {
        if (!dialogVisible)
            return ;

        if (popupMode === "control" && controlLayoutService.editMode)
            controlLayoutService.cancelEdit();

        activityPopupTimer.stop();
        openHandoffTimer.stop();
        popupAcceptsFocus = false;
        popupMenuOpen = false;
        controlLayoutService.resetInteraction();
        if (!panelHidden && !islandOpen) {
            dialogVisible = false;
            return ;
        }
        islandOpen = false;
        closeDialogTimer.restart();
    }

    function focusIslandDialog() {
        popupAcceptsFocus = true;
        if (islandDialog.requestActivate)
            islandDialog.requestActivate();
    }

    function bump(kind) {
        const requestedProvider = kind && kind !== "auto" ? activityController.providerByKey(kind) : null;
        if (requestedProvider && !requestedProvider.active)
            return ;
        if (!hasActivity)
            return ;

        const nextMode = resolvedActivityMode(kind || "auto");
        if (islandOpen && popupMode === "activity" && activityPopupTimer.running && activityPriority(nextMode) < activityPriority(resolvedActivityMode(activityPopupMode))) {
            activityPopupTimer.restart();
            return ;
        }
        showActivityPopup(true, nextMode);
    }

    function showActivityPopup(autoClose, kind) {
        activityPopupMode = resolvedActivityMode(kind || "auto");
        openIsland("activity", autoClose);
    }

    function showControlCenter() {
        keyboardAnnouncementLifetimeTimer.stop();
        keyboardAnnouncementActive = false;
        root.refreshSystemState();
        controlLayoutService.ensureLayout();
        openIsland("control", false);
        Qt.callLater(root.focusIslandDialog);
    }

    function toggleActivityPopup(autoClose) {
        if (islandOpen && popupMode === "activity") {
            closeIsland();
            return ;
        }
        showActivityPopup(autoClose, "auto");
    }

    function toggleControlCenter() {
        if (islandOpen && popupMode === "control") {
            closeIsland();
            return ;
        }
        showControlCenter();
    }

    function notificationStatusText() {
        const count = notificationService.count();
        if (count <= 0)
            return i18n("Quiet");
        if (count === 1)
            return i18n("1 notification");
        return i18np("%1 notification", "%1 notifications", count);
    }

    function activeRowFor(kind) {
        const mode = resolvedActivityMode(kind || "auto");
        if (mode === "notice") {
            const noticeRow = notificationService.firstRowOfType(NotificationManager.Notifications.NotificationType);
            if (noticeRow >= 0)
                return noticeRow;
        }

        if (mode === "job") {
            const jobRow = notificationService.firstRowOfType(NotificationManager.Notifications.JobType);
            if (jobRow >= 0)
                return jobRow;
        }

        const job = notificationService.firstRowOfType(NotificationManager.Notifications.JobType);
        if (job >= 0)
            return job;

        const notice = notificationService.firstRowOfType(NotificationManager.Notifications.NotificationType);
        return notice >= 0 ? notice : 0;
    }

    function activeRow() {
        return activeRowFor("auto");
    }

    function activeJobRow() {
        return notificationService.firstRowOfType(NotificationManager.Notifications.JobType);
    }

    function jobDetails(row) {
        return notificationService.rowValue(row, NotificationManager.Notifications.JobDetailsRole, null);
    }

    function jobTitle(row) {
        const details = jobDetails(row);
        const title = TextUtils.cleanText(details && details.summary ? details.summary : notificationService.rowValue(row, NotificationManager.Notifications.SummaryRole, ""));
        return title.length > 0 ? title : i18n("Working");
    }

    function jobText(row) {
        const details = jobDetails(row);
        const text = TextUtils.cleanText(details && details.text ? details.text : notificationService.rowValue(row, NotificationManager.Notifications.BodyRole, ""));
        if (text.length > 0)
            return text;
        const appName = TextUtils.cleanText(details && details.applicationName ? details.applicationName : notificationService.rowValue(row, NotificationManager.Notifications.ApplicationNameRole, ""));
        return appName;
    }

    function jobIcon(row) {
        const details = jobDetails(row);
        const icon = details && details.applicationIconName ? details.applicationIconName : notificationService.rowValue(row, NotificationManager.Notifications.ApplicationIconNameRole, "");
        if (Utils.hasVisualValue(icon))
            return icon;
        const desktopEntry = TextUtils.cleanText(details && details.desktopEntry ? details.desktopEntry : notificationService.rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        return desktopEntry.length > 0 ? desktopEntry : "folder-download";
    }

    function jobState(row) {
        const details = jobDetails(row);
        if (details && details.state !== undefined)
            return details.state;
        return notificationService.rowValue(row, NotificationManager.Notifications.JobStateRole, NotificationManager.Notifications.JobStateRunning);
    }

    function jobPercentage(row) {
        const details = jobDetails(row);
        const percentage = details && details.percentage !== undefined ? details.percentage : notificationService.rowValue(row, NotificationManager.Notifications.PercentageRole, -1);
        return Math.max(-1, Math.min(100, Math.round(Utils.finiteNumber(percentage, -1))));
    }

    function jobSuspendable(row) {
        const details = jobDetails(row);
        return details && details.suspendable !== undefined ? details.suspendable : Boolean(notificationService.rowValue(row, NotificationManager.Notifications.SuspendableRole, false));
    }

    function jobKillable(row) {
        const details = jobDetails(row);
        return details && details.killable !== undefined ? details.killable : Boolean(notificationService.rowValue(row, NotificationManager.Notifications.KillableRole, false));
    }

    function jobIsSuspended(row) {
        return jobState(row) === NotificationManager.Notifications.JobStateSuspended;
    }

    function toggleJobSuspended(row) {
        if (row < 0 || row >= notificationService.model.count || !jobSuspendable(row))
            return ;
        const idx = notificationService.model.index(row, 0);
        if (jobIsSuspended(row))
            notificationService.model.resumeJob(idx);
        else
            notificationService.model.suspendJob(idx);
    }

    function cancelJob(row) {
        if (row < 0 || row >= notificationService.model.count || !jobKillable(row))
            return ;
        notificationService.model.killJob(notificationService.model.index(row, 0));
    }

    function jobDetailsText(row) {
        const details = jobDetails(row);
        if (!details)
            return jobIsSuspended(row) ? i18n("Paused") : "";
        if (jobIsSuspended(row))
            return i18n("Paused");
        if (Utils.finiteNumber(details.speed, 0) > 0)
            return Utils.formatByteSize(details.speed) + "/s";
        const processed = Utils.finiteNumber(details.processedBytes, 0);
        const total = Utils.finiteNumber(details.totalBytes, 0);
        if (total > 0)
            return i18n("%1 of %2", Utils.formatByteSize(processed), Utils.formatByteSize(total));
        return TextUtils.cleanText(details.applicationName || "");
    }

    function announceKeyboardLayout() {
        if (!keyboardLayoutActivityEnabled)
            return ;
        keyboardAnnouncementActive = true;
        keyboardAnnouncementLifetimeTimer.restart();
        bump("keyboard");
    }

    function primaryTextFor(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider && provider.title.length > 0 ? provider.title : i18n("Control Center");
    }

    function primaryText() {
        return primaryTextFor("auto");
    }

    function secondaryTextFor(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.subtitle : i18n("Brightness, audio, network, power");
    }

    function secondaryText() {
        return secondaryTextFor("auto");
    }

    function resolvedActivityMode(kind) {
        return activityController.keyFor(kind || "auto");
    }

    function activityPriority(kind) {
        return activityController.priorityFor(kind || "auto");
    }

    function activityMode() {
        return activityController.currentKey;
    }

    function popupActivityMode() {
        return popupMode === "activity" ? resolvedActivityMode(activityPopupMode) : activityMode();
    }

    function activityArtworkFor(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.artwork : null;
    }

    function activityProgressVisible(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.progressVisible : false;
    }

    function activityProgressTo(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.progressTo : 1;
    }

    function activityProgressValue(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.progressValue : 0;
    }

    function activityProgressAccent(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.progressAccent : "#5ac8fa";
    }

    function activityShowsMediaControls(kind) {
        const provider = activityController.providerFor(kind || "auto");
        return provider ? provider.mediaControlsVisible : false;
    }

    function screenBrightnessPercent() {
        if (screenBrightnessDisplayName.length > 0 && screenBrightnessMax > 0)
            return Utils.percentFromRatio(screenBrightnessValue, screenBrightnessMax);

        const displays = screenBrightness.displays;
        if (!screenBrightness.isBrightnessAvailable || !displays || displays.count <= 0)
            return 0;

        const idx = displays.index(0, 0);
        const value = Utils.firstValidNumber([displays.data(idx, 258), displays.data(idx, 257)], 0);
        const max = Utils.firstValidNumber([displays.data(idx, 259), displays.data(idx, 260)], 100);
        return Utils.percentFromRatio(value, max);
    }

    function displayedScreenBrightnessPercent() {
        if (!screenBrightness.isBrightnessAvailable)
            return 0;

        return screenBrightnessVisualPinned ? screenBrightnessVisualPercent : screenBrightnessPercent();
    }

    function syncScreenBrightnessDisplay(displayName, value, max) {
        const safeMax = Math.max(1, Math.round(Utils.finiteNumber(max, 100)));
        const safeValue = Math.round(Utils.clampNumber(value, 0, safeMax));
        const percent = Utils.percentFromRatio(safeValue, safeMax);

        screenBrightnessDisplayName = displayName || "";
        screenBrightnessValue = safeValue;
        screenBrightnessMax = safeMax;

        if (!screenBrightnessVisualPinned || Math.abs(percent - screenBrightnessVisualPercent) <= 1) {
            screenBrightnessVisualPercent = percent;
            screenBrightnessVisualPinned = false;
        }
    }

    function setScreenBrightnessPercent(value) {
        if (!screenBrightness.isBrightnessAvailable)
            return ;

        const percent = Math.round(Utils.clampNumber(value, 0, 100));
        screenBrightnessVisualPercent = percent;
        screenBrightnessVisualPinned = true;
        screenBrightnessSettleTimer.restart();

        if (screenBrightnessDisplayName.length > 0 && screenBrightnessMax > 0) {
            screenBrightness.setBrightness(screenBrightnessDisplayName, Math.round(screenBrightnessMax * percent / 100));
        } else {
            screenBrightness.adjustBrightnessRatio((percent - screenBrightnessPercent()) / 100);
        }
    }

    function keyboardBrightnessPercent() {
        if (!keyboardBrightness.isBrightnessAvailable || keyboardBrightness.brightnessMax <= 0)
            return 0;

        const value = Utils.finiteNumber(keyboardBrightness.brightness, 0);
        const max = Utils.finiteNumber(keyboardBrightness.brightnessMax, 0);
        return max > 0 ? Utils.percentFromRatio(value, max) : 0;
    }

    function setKeyboardBrightnessPercent(value) {
        if (!keyboardBrightness.isBrightnessAvailable || keyboardBrightness.brightnessMax <= 0)
            return ;

        const percent = Utils.clampNumber(value, 0, 100);
        keyboardBrightness.brightness = Math.round(keyboardBrightness.brightnessMax * percent / 100);
    }

    function adjustSystemVolume(up) {
        if (up)
            GlobalService.volumeUp();
        else
            GlobalService.volumeDown();
    }

    function defaultSink() {
        return PreferredDevice.sink || null;
    }

    // Faint 1px top highlight on the Pill surfaces (the Notch has none); set to 0 to disable.
    readonly property real rimLight: 0.12
    property string idleHoverTitle: ""
    property string idleHoverText: ""
    property string idleClickTarget: ""
    readonly property alias weather: weatherService
    readonly property alias launcher: appLauncher
    readonly property alias layoutService: controlLayoutService
    readonly property alias media: mediaService
    readonly property alias notifications: notificationService

    WeatherService {
        id: weatherService
    }

    // Bound to the default sink, so external mute changes and sink switches update every user.
    readonly property bool systemAudioAvailable: PreferredDevice.sink !== null && PreferredDevice.sink !== undefined
    readonly property bool systemMuted: systemAudioAvailable && PreferredDevice.sink.muted === true

    function systemVolumePercent() {
        const sink = defaultSink();
        if (!sink)
            return 0;

        const volume = Utils.finiteNumber(sink.volume, 0);
        return Math.max(0, Math.min(150, Utils.percentFromRatio(volume, PulseAudio.NormalVolume)));
    }

    function setSystemVolumePercent(value) {
        const sink = defaultSink();
        if (!sink)
            return ;

        const percent = Utils.clampNumber(value, 0, 150);
        sink.muted = false;
        sink.volume = Math.round(PulseAudio.NormalVolume * percent / 100);
    }

    function toggleSystemMute() {
        const sink = defaultSink();
        if (sink)
            sink.muted = !sink.muted;
        else
            GlobalService.globalMute();
    }

    function lockScreen() {
        commands.run("loginctl lock-session");
        closeIsland();
    }

    function runPowerAction(action) {
        if (action === "lock")
            commands.run("loginctl lock-session");
        else if (action === "logout")
            commands.run("qdbus6 org.kde.Shutdown /Shutdown logout");
        else if (action === "sleep")
            commands.run("systemctl suspend");
        else if (action === "hibernate")
            commands.run("systemctl hibernate");
        else if (action === "reboot")
            commands.run("systemctl reboot");
        else if (action === "shutdown")
            commands.run("systemctl poweroff");
        closeIsland();
    }

    function toggleBluetoothPower() {
        commands.run(bluetoothPowered ? "bluetoothctl power off" : "bluetoothctl power on");
        bluetoothRefreshTimer.restart();
    }

    function toggleAppearanceMode() {
        Brightness.DarkModeControl.darkMode = !Brightness.DarkModeControl.darkMode;
    }

    function profileFaceUrl() {
        if (profileImageUrl.length > 0)
            return profileImageUrl;

        const user = systemUsername || "";
        return user.length > 0 ? "file:///var/lib/AccountsService/icons/" + user : "";
    }

    function refreshSystemState() {
        commands.run("whoami", stdout => systemUsername = TextUtils.cleanText(stdout));
        commands.run("hostname", stdout => systemHostname = TextUtils.cleanText(stdout));
        commands.run(accountIconCommand, applyAccountIcon);
        refreshConnectivityState();
    }

    function applyAccountIcon(stdout) {
        const out = TextUtils.cleanText(stdout);
        profileImageUrl = out.length > 0 ? (out.indexOf("file:") === 0 ? out : "file://" + out) : "";
    }

    function refreshConnectivityState() {
        refreshBluetoothState();
        refreshWifiNetworks();
        refreshKdeConnectState();
    }

    function refreshBluetoothState() {
        commands.run("bluetoothctl show", stdout => {
            bluetoothAvailable = parseBluetoothAvailable(stdout);
            bluetoothAdapterName = parseBluetoothAdapterName(stdout);
            bluetoothPowered = TextUtils.cleanText(stdout).indexOf("Powered: yes") !== -1;
        });
        commands.run("bluetoothctl devices Connected", stdout => bluetoothDevicesText = parseBluetoothDevices(stdout));
    }

    function refreshKdeConnectState() {
        commands.run(KdeConnectState.pairedCommand, stdout => kdeConnectPaired = KdeConnectState.parseNames(stdout));
        commands.run(KdeConnectState.connectedCommand, stdout => kdeConnectConnected = KdeConnectState.parseNames(stdout));
    }

    function toggleWifi() {
        networkHandler.enableWireless(!enabledConnections.wirelessEnabled);
        wifiRefreshTimer.restart();
    }

    function refreshWifiNetworks() {
        commands.run(wifiScanCommand, stdout => wifiNetworks = NetworkState.parseWifi(stdout));
        commands.run(networkStatusCommand, stdout => networkDevices = NetworkState.parseDevices(stdout));
        commands.run(networkIpCommand, stdout => networkAddresses = NetworkState.parseAddresses(stdout));
    }

    function wifiTitle() {
        if (!enabledConnections.wirelessHwEnabled)
            return i18n("Unavailable");
        return enabledConnections.wirelessEnabled ? i18n("On") : i18n("Off");
    }

    function wifiPrimaryNetwork() {
        return networkState.wifiSummary;
    }

    function wifiSignalPercent() {
        return Math.max(0, networkState.wifiSignal);
    }

    function parseBluetoothDevices(text) {
        const lines = String(text || "").split("\n");
        const out = [];
        for (let i = 0; i < lines.length; ++i) {
            const line = String(lines[i] || "").trim();
            if (line.length <= 0)
                continue;

            const parts = line.split(/\s+/);
            out.push(parts.length > 2 ? parts.slice(2).join(" ") : line);
        }
        return out.join("\n");
    }

    function parseBluetoothAvailable(text) {
        const out = String(text || "");
        return out.indexOf("Controller ") !== -1 || out.indexOf("Powered:") !== -1 || out.indexOf("Alias:") !== -1;
    }

    function parseBluetoothAdapterName(text) {
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = String(lines[i] || "").trim();
            if (line.indexOf("Alias:") === 0)
                return TextUtils.cleanText(line.slice(6));
            if (line.indexOf("Name:") === 0)
                return TextUtils.cleanText(line.slice(5));
        }
        return "";
    }

    function bluetoothDeviceCount() {
        if (bluetoothDevicesText.length <= 0)
            return 0;
        return bluetoothDevicesText.split("\n").filter(function(line) {
            return String(line || "").trim().length > 0;
        }).length;
    }

    function bluetoothSummary() {
        if (!bluetoothAvailable)
            return i18n("No adapter");
        if (!bluetoothPowered)
            return i18n("Off");
        const count = bluetoothDeviceCount();
        if (count <= 0)
            return i18n("On");
        return count === 1 ? bluetoothDevicesText.split("\n")[0] : i18np("%1 device", "%1 devices", count);
    }

    function bluetoothDetail() {
        if (!bluetoothAvailable)
            return i18n("Bluetooth adapter unavailable");
        if (!bluetoothPowered)
            return i18n("Radio disabled");
        if (bluetoothDevicesText.length > 0)
            return bluetoothDevicesText;
        return bluetoothAdapterName.length > 0 ? bluetoothAdapterName : i18n("No connected devices");
    }

    function kdeConnectDevices(limit) {
        const all = KdeConnectState.buildDevices(kdeConnectPaired, kdeConnectConnected);
        const maxRows = Math.max(0, Math.round(Utils.finiteNumber(limit, 0)));
        return maxRows > 0 ? all.slice(0, maxRows) : all;
    }

    function kdeConnectReachableCount() {
        return KdeConnectState.connectedCount(kdeConnectDevices(0));
    }

    function kdeConnectSummary() {
        const devices = kdeConnectDevices(0);
        const kind = KdeConnectState.summaryKind(devices);
        if (kind === "connected")
            return i18np("%1 connected", "%1 connected", KdeConnectState.connectedCount(devices));
        return kind === "away" ? i18n("Not nearby") : i18n("No devices");
    }

    function refreshKdeConnectDevices() {
        commands.run("kdeconnect-cli --refresh");
        refreshKdeConnectState();
    }

    function runKdeConnectDeviceAction(deviceId, action) {
        const id = TextUtils.cleanText(deviceId);
        if (id.length <= 0)
            return ;

        if (action === "ring")
            commands.run("kdeconnect-cli --device " + Utils.shellQuote(id) + " --ring");
        else if (action === "browse")
            commands.run("qdbus6 org.kde.kdeconnect /modules/kdeconnect/devices/" + id + "/sftp org.kde.kdeconnect.device.sftp.startBrowsing");
    }

    function cyclePowerProfile() {
        const profiles = powerProfiles.profiles;
        if (!profiles || profiles.length <= 0)
            return ;

        const current = profiles.indexOf(powerProfiles.activeProfile);
        const next = profiles[(Math.max(0, current) + 1) % profiles.length];
        powerProfiles.setProfile(next);
    }

    function powerProfileIcon() {
        if (powerProfiles.activeProfile === "performance")
            return "battery-profile-performance";

        if (powerProfiles.activeProfile === "power-saver")
            return "battery-profile-powersave";

        return "battery-profile-balanced";
    }

    function powerProfileTitle() {
        if (powerProfiles.activeProfile === "performance")
            return i18n("Performance");
        if (powerProfiles.activeProfile === "power-saver")
            return i18n("Saver");
        return i18n("Balanced");
    }

    function batteryText() {
        if (!batteryControl.hasInternalBatteries)
            return batteryControl.pluggedIn ? i18n("AC") : i18n("Power");

        return batteryControl.percent + "%";
    }

    Layout.minimumWidth: islandWidth
    Layout.maximumWidth: islandWidth
    Layout.preferredWidth: islandWidth
    Layout.minimumHeight: islandHeight
    Layout.maximumHeight: islandHeight
    Layout.preferredHeight: islandHeight
    switchWidth: islandWidth
    switchHeight: islandHeight
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.status: hasActivity ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.title: i18n("Dynamic Island")
    toolTipMainText: idleHoverTitle.length > 0 && !hasActivity ? idleHoverTitle : primaryText()
    toolTipTextFormat: idleHoverTitle.length > 0 && !hasActivity ? Text.RichText : Text.AutoText
    toolTipSubText: idleHoverTitle.length > 0 && !hasActivity ? idleHoverText : secondaryText()
    compactRepresentation: islandComponent
    fullRepresentation: emptyFullRepresentation
    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: true
    onExpandedChanged: function() {
        if (expanded)
            expanded = false;

    }

    onNotchShapeChanged: Qt.callLater(syncPanel)

    // Startup sync is delayed until the shell's scripting service is up, and
    // retried a couple of times if a request never answers.
    Timer {
        id: panelStartTimer

        interval: 2500
        repeat: false
        onTriggered: root.syncPanel()
    }

    Timer {
        id: panelWatchdog

        interval: 8000
        repeat: false
        onTriggered: {
            root.panelSyncPhase = 0;
            if (root.panelSyncAttempts++ < 2)
                panelStartTimer.restart();
        }
    }

    KeyboardLayout.KeyboardLayout {
        id: keyboardLayout

        property bool announcementReady: false

        Component.onCompleted: Qt.callLater(function() {
            keyboardLayout.announcementReady = true;
        })
        onLayoutChanged: {
            if (announcementReady)
                root.announceKeyboardLayout();
        }
    }

    Activities.ActivityController {
        id: activityController

        providers: [
            Activities.ActivityProvider {
                key: "keyboard"
                active: root.keyboardAnnouncementActive
                priority: 350
                title: root.keyboardLayoutLongName
                subtitle: root.keyboardLayoutDisplayName
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: keyboardVisualComponent
                expandedComponent: keyboardExpandedComponent
            },
            Activities.ActivityProvider {
                key: "job"
                active: root.jobActivityEnabled && root.hasJobs
                priority: 300
                title: root.jobTitle(root.activeJobRow())
                subtitle: root.jobText(root.activeJobRow())
                progressVisible: root.jobPercentage(root.activeJobRow()) >= 0
                progressTo: 100
                progressValue: Math.max(0, root.jobPercentage(root.activeJobRow()))
                progressAccent: "#42d77d"
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: jobVisualComponent
                compactComponent: jobCompactComponent
                expandedComponent: jobExpandedComponent
            },
            Activities.ActivityProvider {
                key: "notice"
                active: notificationService.activityActive
                priority: notificationService.urgency(notificationService.latestRow()) >= 2 ? 400 : 200
                title: notificationService.title(notificationService.latestRow())
                subtitle: notificationService.body(notificationService.latestRow())
                artwork: notificationService.mainImage(notificationService.latestRow())
                autoCloseMs: notificationService.durationMs
                visualComponent: noticeVisualComponent
                compactComponent: notificationCompactComponent
                expandedComponent: notificationActivityPage
            },
            Activities.ActivityProvider {
                key: "media"
                active: root.mediaActivityEnabled && mediaService.shown
                priority: 100
                title: mediaService.hasPlayer ? mediaService.player.track || mediaService.player.identity || "Media" : "Media"
                subtitle: mediaService.hasPlayer ? mediaService.player.artist || mediaService.player.album || mediaService.player.identity || "" : ""
                artwork: mediaService.hasPlayer ? mediaService.player.artUrl : ""
                progressVisible: mediaService.hasPlayer && mediaService.length > 0
                progressTo: Math.max(1, mediaService.hasPlayer ? mediaService.length : 1)
                progressValue: mediaService.hasPlayer ? mediaService.player.position : 0
                progressAccent: "#5ac8fa"
                mediaControlsVisible: mediaService.hasPlayer
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: mediaVisualComponent
                compactComponent: musicCompactComponent
                expandedComponent: musicExpandedComponent
            },
            Activities.ActivityProvider {
                key: "idle"
                active: true
                priority: 0
                title: i18n("Control Center")
                subtitle: i18n("Brightness, audio, network, power")
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: idleVisualComponent
                expandedComponent: activityPage
            }
        ]
    }

    Brightness.ScreenBrightnessControl {
        id: screenBrightness

        isSilent: true
    }

    Instantiator {
        model: screenBrightness.displays

        delegate: QtObject {
            required property int index
            required property string displayName
            required property int brightness
            required property int maxBrightness

            function syncIfPrimary() {
                if (index === 0)
                    root.syncScreenBrightnessDisplay(displayName, brightness, maxBrightness);
            }

            Component.onCompleted: syncIfPrimary()
            onBrightnessChanged: syncIfPrimary()
            onMaxBrightnessChanged: syncIfPrimary()
            onDisplayNameChanged: syncIfPrimary()
        }
    }

    Timer {
        id: screenBrightnessSettleTimer

        interval: 900
        repeat: false
        onTriggered: {
            root.screenBrightnessVisualPinned = false;
            root.screenBrightnessVisualPercent = root.screenBrightnessPercent();
        }
    }

    Brightness.KeyboardBrightnessControl {
        id: keyboardBrightness

        isSilent: true
    }

    PowerProfilesControl {
        id: powerProfiles

        isSilent: true
    }

    BatteryControlModel {
        id: batteryControl
    }

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    PlasmaNM.WirelessStatus {
        id: wirelessStatus
    }

    PlasmaNM.Handler {
        id: networkHandler
    }

    CommandRunner {
        id: commands
    }

    NotificationService {
        id: notificationService

        launcher: appLauncher
        activityEnabled: root.notificationActivityEnabled
        bodyCharacters: root.notificationBodyCharacters
        popupDurationMs: root.notificationPopupDurationMs
        fallbackAppName: i18n("Notification")
        holdLifetime: root.holdNoticeLifetime
        popupTimerRunning: activityPopupTimer.running
        onNoticeShown: root.bump("notice")
        onJobArrived: root.bump("job")
        onDismissed: (closePopup, wasShowing) => {
            if (wasShowing && closePopup && root.dialogVisible && root.popupMode === "activity" && root.activityPopupMode === "notice")
                root.closeIsland();
        }
        onOpened: {
            if (root.dialogVisible)
                root.closeIsland();
        }
    }

    MediaService {
        id: mediaService

        positionPolling: root.mediaPositionVisible
        onMediaEvent: root.bump("media")
    }

    ControlLayout {
        id: controlLayoutService

        storedJson: String(root.settings.controlCenterLayoutJson || "")
        dragHost: dialogHost
        iconState: ({
            "wifiEnabled": enabledConnections.wirelessEnabled,
            "batteryCharging": batteryControl.pluggedIn,
            "powerProfileIcon": root.powerProfileIcon()
        })
        onSaveRequested: json => root.settings.controlCenterLayoutJson = json
    }

    AppLauncher {
        id: appLauncher

        runner: commands
        configuredCalendarApp: String(root.settings.calendarApp || "")
        forecastAvailable: weatherService.configured
        forecastUrl: weatherService.forecastUrl
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }

    Component.onCompleted: {
                if (root.panelSyncWanted())
            panelStartTimer.start();
        controlLayoutService.ensureLayout();
        root.refreshSystemState();
        appLauncher.discoverCalendarApp();
        root.lastActiveJobsCount = notificationService.model.activeJobsCount;
    }

    Connections {
        function onActiveJobsCountChanged() {
            const count = notificationService.model.activeJobsCount;
            if (count > root.lastActiveJobsCount)
                root.bump("job");
            root.lastActiveJobsCount = count;
        }

        target: notificationService.model
    }

    // Shared low-rate clock for every decorative loop (weather icon, AudioBars); idle unless something holds a lease.
    readonly property var decorClock: decorClockItem

    DecorClock {
        id: decorClockItem

        paused: root.fullscreenCovering
    }

    // A fullscreen window on top of the island's screen hides it, so decorative loops and the position poll stop.
    // Event-driven: the task model reports windows as they open, close, minimize or change fullscreen.
    property bool fullscreenCovering: false

    function updateFullscreen() {
        const tasks = [];
        for (let i = 0; i < fullscreenModel.count; ++i) {
            const idx = fullscreenModel.index(i, 0);
            tasks.push({
                "isWindow": fullscreenModel.data(idx, TaskManager.AbstractTasksModel.IsWindow),
                "fullScreen": fullscreenModel.data(idx, TaskManager.AbstractTasksModel.IsFullScreen),
                "minimized": fullscreenModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized)
            });
        }
        fullscreenCovering = FullscreenState.covering(tasks);
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: fullscreenModel

        filterByVirtualDesktop: true
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByScreen: true
        screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
        groupMode: TaskManager.TasksModel.GroupDisabled
        onCountChanged: root.updateFullscreen()
        onDataChanged: root.updateFullscreen()
        Component.onCompleted: root.updateFullscreen()
    }

    PausableTimer {
        id: activityPopupTimer

        duration: activityController.autoCloseMsFor(root.activityPopupMode)
        hold: root.holdPopupTimers
        onTriggered: {
            if (root.popupMode === "activity")
                root.closeIsland();

        }
    }

    Timer {
        id: keyboardAnnouncementLifetimeTimer

        interval: root.ongoingPopupDurationMs + 420
        repeat: false
        onTriggered: root.keyboardAnnouncementActive = false
    }

    Timer {
        id: closeDialogTimer

        interval: 360
        repeat: false
        onTriggered: {
            if (!root.islandOpen) {
                root.dialogVisible = false;
                root.panelHidden = false;
                if (root.keyboardAnnouncementActive) {
                    keyboardAnnouncementLifetimeTimer.stop();
                    root.keyboardAnnouncementActive = false;
                }
            }
        }
    }

    Timer {
        id: openHandoffTimer

        interval: 18
        repeat: false
        onTriggered: {
            root.panelHidden = true;
            root.islandOpen = true;
        }
    }

    Timer {
        id: clickTimer

        interval: 210
        repeat: false
        onTriggered: {
            if (root.clickButton === Qt.MiddleButton && mediaService.player)
                mediaService.playPause();
            else if (root.islandOpen)
                root.closeIsland();
            else if (root.dialogVisible)
                root.closeIsland();
            else if (root.hasActivity) {
                root.showActivityPopup(false);
                Qt.callLater(root.focusIslandDialog);
            } else if (root.idleClickTarget === "time") {
                appLauncher.openCalendar();
            } else if (root.idleClickTarget === "weather") {
                appLauncher.openForecast();
            } else {
                root.showControlCenter();
            }
        }
    }

    Timer {
        id: bluetoothRefreshTimer

        interval: 900
        repeat: false
        onTriggered: {
            root.refreshBluetoothState();
        }
    }

    Timer {
        // Connectivity is only shown in the control center. Avoid running
        // subprocesses in the background while the island is idle.
        interval: 30000
        repeat: true
        running: root.dialogVisible && root.popupMode === "control"
        triggeredOnStart: false
        onTriggered: root.refreshConnectivityState()
    }

    Timer {
        id: wifiRefreshTimer

        interval: 900
        repeat: false
        onTriggered: root.refreshWifiNetworks()
    }

    PlasmaCore.Dialog {
        id: islandDialog

        appletInterface: root
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.Dock
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | (root.popupAcceptsFocus ? 0 : Qt.WindowDoesNotAcceptFocus)
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: root.dialogVisible
        onVisibleChanged: {
            if (visible) {
                Qt.callLater(root.positionIslandDialog);
            } else {
                root.popupAcceptsFocus = false;
                root.popupMenuOpen = false;
                root.dialogActive = false;
            }
        }
        onActiveChanged: {
            if (active) {
                root.dialogActive = true;
                return;
            }
            const shouldClose = root.dialogActive && root.dialogVisible && root.islandOpen && !root.popupMenuOpen;
            root.dialogActive = false;
            if (shouldClose)
                root.closeIsland();
        }
        onWidthChanged: root.positionIslandDialog()
        onHeightChanged: root.positionIslandDialog()

        mainItem: Item {
            id: dialogHost

            width: root.popupWidth
            height: root.popupHeight

            Loader {
                id: dialogLoader

                anchors.fill: parent
                active: root.dialogVisible
                sourceComponent: popupComponent
            }

            Rectangle {
                id: controlDragPreview

                width: controlLayoutService.dragSize
                height: controlLayoutService.dragSize
                x: controlLayoutService.dragX
                y: controlLayoutService.dragY
                radius: 17
                visible: controlLayoutService.editMode && (controlLayoutService.dragActive || opacity > 0)
                opacity: controlLayoutService.dragActive ? 0.92 : 0
                color: "#20212a"
                border.color: "#8e8eff"
                border.width: 1
                z: 1000

                Drag.active: controlLayoutService.dragActive
                Drag.source: controlLayoutService.dragSource
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                Behavior on opacity {
                    NumberAnimation { duration: 90 }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.min(30, parent.width - 18)
                    height: width
                    source: controlLayoutService.dragIcon
                    color: "#f8f8fb"
                }
            }
        }

    }

    Component {
        id: idleVisualComponent

        Item {
        }
    }

    Component {
        id: mediaVisualComponent

        MaskedArtwork {
            artworkSource: mediaService.hasPlayer ? mediaService.player.artUrl : ""
            cornerRadius: root.notchShape ? Math.round(Math.min(width, height) * 0.3) : Math.min(width, height) / 2 // notch: rounded square like expanded; pill: circle
            mode: "media"
            progress: root.activityProgressValue("media") / Math.max(1, root.activityProgressTo("media"))
            playing: mediaService.isPlaying
        }
    }

    Component {
        id: jobVisualComponent

        MaskedArtwork {
            mode: "job"
            progress: root.activityProgressValue("job") / Math.max(1, root.activityProgressTo("job"))
            playing: !root.jobIsSuspended(root.activeJobRow())
        }
    }

    Component {
        id: keyboardVisualComponent

        Rectangle {
            radius: Math.min(width, height) / 2
            color: "#1b1b25"
            border.color: "#3d3d50"
            border.width: 1

            PlasmaLabel {
                anchors.centerIn: parent
                text: root.keyboardLayoutShortName.toUpperCase()
                color: "#e2e2ed"
                font.pixelSize: Math.max(8, Math.min(11, parent.height * 0.42))
                font.weight: Font.Bold
            }
        }
    }

    Component {
        id: noticeVisualComponent

        Activities.NotificationVisual {
            source: notificationService.appIcon(notificationService.latestRow())
            fallbackSource: "notifications"
            fallbackColor: notificationService.accent(notificationService.latestRow())
        }
    }

    Component {
        id: notificationActivityPage

        Activities.NotificationExpanded {
            app: root
        }
    }

    Component {
        id: musicCompactComponent

        Activities.MusicCompact {
            app: root
        }
    }

    Component {
        id: musicExpandedComponent

        Activities.MusicExpanded {
            app: root
        }
    }

    Component {
        id: notificationCompactComponent

        Activities.NotificationCompact {
            app: root
        }
    }

    Component {
        id: jobCompactComponent

        Activities.JobCompact {
            app: root
        }
    }

    Component {
        id: jobExpandedComponent

        Activities.JobExpanded {
            app: root
        }
    }

    Component {
        id: keyboardExpandedComponent

        Activities.KeyboardLayoutExpanded {
            app: root
        }
    }

    Component {
        id: islandComponent

        Item {
            id: island

            width: root.islandWidth
            height: root.islandHeight
            scale: 1
            opacity: root.panelHidden ? 0 : 1

            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                Accessible.role: Accessible.Button
                Accessible.name: i18n("Dynamic Island")
                Accessible.description: root.primaryText() + ". " + root.secondaryText()
                Accessible.onPressAction: root.toggleControlCenter()
                onClicked: (mouse) => {
                    root.clickButton = mouse.button;
                    root.idleClickTarget = !root.hasActivity && mouse.button === Qt.LeftButton ? idleFace.targetAt(mouse.x, mouse.y) : "";
                    // Time/weather launch only after the double-click window, so a double click always wins.
                    clickTimer.interval = root.idleClickTarget !== "" ? Qt.styleHints.mouseDoubleClickInterval : 210;
                    clickTimer.restart();
                }
                onDoubleClicked: (mouse) => {
                    clickTimer.stop();
                    root.toggleControlCenter();
                }
                onWheel: (wheel) => {
                    if (mediaService.player && mediaService.player.changeVolume)
                        mediaService.player.changeVolume(wheel.angleDelta.y > 0 ? 0.04 : -0.04, true);
                    else
                        root.adjustSystemVolume(wheel.angleDelta.y > 0);
                }
            }

            NotchShape {
                anchors.fill: parent
                visible: root.notchShape
                shoulder: root.notchShoulder
                bottomRadius: root.notchBottomRadius
            }

            RoundShape {
                id: capsule

                visible: !root.notchShape
                anchors.fill: parent
                rimOpacity: root.rimLight
            }

            IdleContent {
                id: idleFace

                anchors.fill: parent
                app: root
                sideMargin: root.notchShape ? 18 : 16
                animate: !root.hasActivity && !root.islandOpen && !root.panelHidden
                opacity: root.hasActivity ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.notchShape ? root.notchSideMargin + 2 : (root.activityMode() === "media" ? 4 : 6)
                anchors.rightMargin: root.notchShape ? root.notchSideMargin : 6
                anchors.topMargin: 4
                anchors.bottomMargin: root.notchShape ? 6 : 4
                spacing: 5

                Rectangle {
                    Layout.preferredWidth: root.compactArtworkSize
                    Layout.preferredHeight: root.compactArtworkSize
                    color: "transparent"

                    Loader {
                        anchors.fill: parent
                        sourceComponent: activityController.visualComponentFor(root.activityMode())
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        anchors.fill: parent
                        active: root.hasActivity
                        sourceComponent: activityController.compactComponentFor(root.activityMode())
                    }

                }

            }

        }

    }

    Component {
        id: emptyFullRepresentation

        Item {
            implicitWidth: root.islandWidth
            implicitHeight: root.islandHeight
            width: implicitWidth
            height: implicitHeight
            visible: false
        }

    }

    Component {
        id: popupComponent

        MouseArea {
            id: popupRoot

            property real morph: root.islandOpen ? 1 : 0
            readonly property real contentOpacity: Math.max(0, Math.min(1, (morph - 0.42) / 0.58))
            readonly property real compactOpacity: Math.max(0, Math.min(1, (0.34 - morph) / 0.34))
            readonly property real collapsedWidth: root.realIslandWidth
            readonly property real collapsedHeight: root.realIslandHeight
            readonly property real panelWidth: collapsedWidth + (root.popupWidth - collapsedWidth) * morph
            readonly property real panelHeight: collapsedHeight + (root.popupHeight - collapsedHeight) * morph
            readonly property real collapsedRadius: root.notchShape ? root.notchBottomRadius : collapsedHeight / 2
            readonly property real panelRadius: collapsedRadius + (root.popupRadius - collapsedRadius) * morph
            readonly property real panelX: root.popupCollapsedX * (1 - morph)
            readonly property real panelY: root.popupCollapsedY * (1 - morph)

            implicitWidth: root.popupWidth
            implicitHeight: root.popupHeight
            width: root.popupWidth
            height: root.popupHeight
            Layout.minimumWidth: root.popupWidth
            Layout.maximumWidth: root.popupWidth
            Layout.preferredWidth: root.popupWidth
            Layout.minimumHeight: root.popupHeight
            Layout.maximumHeight: root.popupHeight
            Layout.preferredHeight: root.popupHeight
            hoverEnabled: true
            focus: root.popupAcceptsFocus
            acceptedButtons: Qt.LeftButton
            Accessible.role: Accessible.Grouping
            Accessible.name: i18n("Dynamic Island")
            Accessible.description: root.primaryText() + ". " + root.secondaryText()
            Keys.onPressed: (event) => {
                if (event.key !== Qt.Key_Escape)
                    return ;

                if (controlLayoutService.dragActive || controlLayoutService.resizeActive)
                    controlLayoutService.resetInteraction();
                else if (controlLayoutService.editMode)
                    controlLayoutService.cancelEdit();
                else
                    root.closeIsland();

                event.accepted = true;
            }
            onClicked: (mouse) => {
                root.closeIsland();
                mouse.accepted = true;
            }
            opacity: 1

            Rectangle {
                id: popupShadow

                x: popupRoot.panelX
                y: popupRoot.panelY
                width: popupRoot.panelWidth
                height: popupRoot.panelHeight
                radius: popupRoot.panelRadius
                color: "#050507"
                opacity: 0
            }

            Rectangle {
                id: contentPanel

                x: popupShadow.x
                y: popupShadow.y
                width: popupShadow.width
                height: popupShadow.height
                radius: popupShadow.radius
                color: "transparent"
                clip: true

                RoundShape {
                    anchors.fill: parent
                    visible: !root.notchShape
                    radius: popupRoot.panelRadius
                    fillTop: root.popupMode === "control" ? "#141419" : "#121216"
                    fillBottom: root.popupMode === "control" ? "#09090c" : "#060608"
                    strokeColor: root.popupMode === "control" ? "#25252b" : "#202027"
                    rimOpacity: root.rimLight
                }

                // Notch mode: the same silhouette as the collapsed shell, grown downward.
                NotchShape {
                    anchors.fill: parent
                    visible: root.notchShape
                    shoulder: root.notchShoulder
                    bottomRadius: popupRoot.panelRadius
                    fillTop: root.popupMode === "control" ? "#141419" : "#121216"
                    fillBottom: root.popupMode === "control" ? "#09090c" : "#060608"
                    strokeColor: root.popupMode === "control" ? "#25252b" : "#202027"
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    enabled: root.islandOpen
                    propagateComposedEvents: true
                    onClicked: (mouse) => {
                        root.closeIsland();
                        mouse.accepted = false;
                    }
                }

                // Clickable notice popup (D-31): the whole island is the target, so the highlight and hit area
                // follow the shell silhouette instead of the inset content area.
                RoundShape {
                    anchors.fill: parent
                    visible: !root.notchShape && opacity > 0
                    opacity: noticeHover.hovered && noticeOpenArea.noticeClickable ? 1 : 0
                    radius: popupRoot.panelRadius
                    fillTop: "#14ffffff"
                    fillBottom: "#0cffffff"
                    strokeColor: "transparent"

                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                NotchShape {
                    anchors.fill: parent
                    visible: root.notchShape && opacity > 0
                    opacity: noticeHover.hovered && noticeOpenArea.noticeClickable ? 1 : 0
                    shoulder: root.notchShoulder
                    bottomRadius: popupRoot.panelRadius
                    fillTop: "#14ffffff"
                    fillBottom: "#0cffffff"
                    strokeColor: "transparent"

                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                // A HoverHandler is passive, so items above the popup (labels, icons) can't take the hover away
                // the way they did from a MouseArea's containsMouse, which made the highlight flicker.
                HoverHandler {
                    id: noticeHover

                    enabled: root.islandOpen && root.popupMode === "activity"
                    cursorShape: noticeOpenArea.noticeClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                Binding {
                    target: root
                    property: "noticeHovered"
                    value: noticeHover.enabled && noticeHover.hovered && noticeOpenArea.noticeClickable
                }

                Binding {
                    target: root
                    property: "popupHovered"
                    value: noticeHover.enabled && noticeHover.hovered
                }

                MouseArea {
                    id: noticeOpenArea

                    readonly property int noticeRow: root.popupMode === "activity" && root.popupActivityMode() === "notice" ? notificationService.latestRow() : -1
                    readonly property bool noticeClickable: noticeRow >= 0 && notificationService.clickable(noticeRow)

                    anchors.fill: parent
                    enabled: root.islandOpen && noticeClickable
                    // Single click opens immediately; the notice popup has no double-click behaviour.
                    onClicked: notificationService.openById(notificationService.rowValue(noticeRow, NotificationManager.Notifications.IdRole, null))
                }

                Loader {
                    // The notch body is narrower than the window by its shoulders, so it
                    // needs extra side padding (and a bit more top/bottom) to breathe.
                    anchors.fill: parent
                    anchors.leftMargin: (root.popupMode === "control" ? 14 : 12) + (root.notchShape ? root.notchShoulder + 2 : 0)
                    anchors.rightMargin: root.popupMode === "control" ? (root.notchShape ? 22 : anchors.leftMargin) : (anchors.leftMargin + (root.notchShape ? 0 : 3))
                    anchors.topMargin: root.popupMode === "control" ? 12 : (root.notchShape ? 14 : 10)
                    anchors.bottomMargin: root.popupMode === "control" ? 16 : anchors.topMargin - 2
                    opacity: popupRoot.contentOpacity
                    visible: opacity > 0
                    sourceComponent: root.popupMode === "control" ? controlCenterPage : activityController.expandedComponentFor(root.popupActivityMode())
                }

                IdleContent {
                    anchors.fill: parent
                    app: root
                    primary: false
                    sideMargin: root.notchShape ? 18 : 16
                    animate: false
                    opacity: root.hasActivity ? 0 : popupRoot.compactOpacity
                    visible: opacity > 0
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.notchShape ? root.notchSideMargin + 2 : (root.popupActivityMode() === "media" ? 4 : 6)
                    anchors.rightMargin: root.notchShape ? root.notchSideMargin : 6
                    anchors.topMargin: 4
                    anchors.bottomMargin: root.notchShape ? 6 : 4
                    spacing: 5
                    opacity: popupRoot.compactOpacity
                    visible: opacity > 0

                    Rectangle {
                        Layout.preferredWidth: root.compactArtworkSize
                        Layout.preferredHeight: root.compactArtworkSize
                        color: "transparent"

                        Loader {
                            anchors.fill: parent
                            sourceComponent: activityController.visualComponentFor(root.popupActivityMode())
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Loader {
                            anchors.fill: parent
                            active: root.hasActivity
                            sourceComponent: activityController.compactComponentFor(root.popupActivityMode())
                        }

                    }

                }

                // The popup only takes keyboard focus after an explicit press inside it (never on hover: changing
                // the window flags re-configures the surface). The press is passed on to whatever is underneath.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: (mouse) => {
                        if (!root.dialogActive)
                            root.focusIslandDialog();
                        mouse.accepted = false;
                    }
                }

            }

            Behavior on morph {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.82, 0.18, 1, 1, 1]
                }

            }

        }

    }

    Component {
        id: activityPage

        RowLayout {
            anchors.fill: parent
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                radius: 16
                color: "transparent"

                MaskedArtwork {
                    anchors.fill: parent
                    artworkSource: root.activityArtworkFor(root.popupActivityMode())
                    cornerRadius: 16
                    glyphSize: 32
                    mode: root.popupActivityMode()
                    progress: root.activityProgressValue(root.popupActivityMode()) / Math.max(1, root.activityProgressTo(root.popupActivityMode()))
                    playing: root.popupActivityMode() === "media" ? mediaService.isPlaying : root.popupActivityMode() === "job" ? !root.jobIsSuspended(root.activeJobRow()) : false
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: root.primaryTextFor(root.popupActivityMode())
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: root.secondaryTextFor(root.popupActivityMode())
                    color: "#9d9da7"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                ProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    visible: root.activityProgressVisible(root.popupActivityMode())
                    from: 0
                    to: root.activityProgressTo(root.popupActivityMode())
                    value: root.activityProgressValue(root.popupActivityMode())
                    accent: root.activityProgressAccent(root.popupActivityMode())
                }

            }

            RowLayout {
                visible: root.activityShowsMediaControls(root.popupActivityMode())
                spacing: 6

                IslandButton {
                    iconName: "media-skip-backward"
                    compact: true
                    tooltipText: i18n("Previous")
                    enabled: mediaService.player && mediaService.player.canGoPrevious
                    onClicked: mediaService.previous()
                }

                IslandButton {
                    iconName: mediaService.isPlaying ? "media-playback-pause" : "media-playback-start"
                    compact: true
                    emphasized: true
                    tooltipText: mediaService.isPlaying ? i18n("Pause") : i18n("Play")
                    enabled: mediaService.player && (mediaService.player.canPlay || mediaService.player.canPause)
                    onClicked: mediaService.playPause()
                }

                IslandButton {
                    iconName: "media-skip-forward"
                    compact: true
                    tooltipText: i18n("Next")
                    enabled: mediaService.player && mediaService.player.canGoNext
                    onClicked: mediaService.next()
                }

            }

        }

    }

    Component {
        id: controlModuleCardDelegate

        ControlCenterModuleCard {
            anchors.fill: parent
            app: root
            hostItem: dialogHost
            notificationsSource: notificationService.model
            batterySource: batteryControl
            connectionsSource: enabledConnections
            screenBrightnessSource: screenBrightness
            keyboardBrightnessSource: keyboardBrightness
            powerProfilesSource: powerProfiles
        }
    }

    Component {
        id: controlCenterPage

        ControlCenterEditor {
            app: root
            hostItem: dialogHost
            moduleCardDelegate: controlModuleCardDelegate
        }
    }

    component MaskedArtwork: Item {
        id: maskedArtwork

        property var artworkSource: ""
        property real cornerRadius: height / 2
        property string mode: "idle"
        property real progress: 0
        property bool playing: false
        property real glyphSize: width * 0.74
        readonly property bool hasArtworkSource: artworkSource && artworkSource.toString().length > 0
        readonly property bool hasArtwork: hasArtworkSource && maskedImage.status === Image.Ready

        Rectangle {
            anchors.fill: parent
            radius: maskedArtwork.cornerRadius
            color: "#101015"
        }

        Image {
            id: maskedImage

            anchors.fill: parent
            source: maskedArtwork.hasArtworkSource ? maskedArtwork.artworkSource : ""
            fillMode: Image.PreserveAspectCrop
            visible: maskedArtwork.hasArtwork
            layer.enabled: visible

            layer.effect: MultiEffect {
                maskEnabled: true
                maskSpreadAtMax: 1
                maskSpreadAtMin: 1
                maskThresholdMin: 0.5

                maskSource: ShaderEffectSource {

                    sourceItem: Rectangle {
                        width: maskedImage.width
                        height: maskedImage.height
                        radius: maskedArtwork.cornerRadius
                        color: "#ffffff"
                    }

                }

            }

        }

        IslandGlyph {
            anchors.centerIn: parent
            width: maskedArtwork.glyphSize
            height: width
            mode: maskedArtwork.mode
            progress: maskedArtwork.progress
            playing: maskedArtwork.playing
            visible: !maskedArtwork.hasArtwork
        }

    }

    component StatusChip: MouseArea {
        id: chip

        property string label: ""
        property bool active: false
        property color dotColor: "#777781"

        implicitHeight: 28
        hoverEnabled: true

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.pressed ? "#303039" : chip.containsMouse ? "#24242b" : "#16161d"
            border.color: chip.active ? "#3a3a44" : "#202027"
            border.width: 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: chip.dotColor
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: chip.label
                color: "#f4f4f8"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

        }

    }

}
