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
import org.kde.plasma.private.mpris as Mpris
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
import "logic/MediaIdle.js" as MediaIdle
import "logic/MediaLength.js" as MediaLength
import "logic/NoticeDuration.js" as NoticeDuration
import "activities" as Activities
import "weather"

PlasmoidItem {
    id: root

    readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge].includes(Plasmoid.location)
    readonly property bool verticalPanel: [PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge].includes(Plasmoid.location)
    readonly property var rawPlayer: mprisModel.currentPlayer
    readonly property var player: {
        mediaPlayerRevision;
        return bestMediaPlayer();
    }
    // Last known track length, held across metadata updates that omit it (see MediaLength.js).
    property real mediaLength: 0
    property var heldLength: null
    function refreshMediaLength() {
        heldLength = MediaLength.hold(heldLength, player ? mediaText(player.identity) + "|" + mediaText(player.track) + "|" + mediaText(player.artist) : "", player ? Utils.finiteNumber(player.length, 0) : 0);
        mediaLength = heldLength.length;
    }
    onMediaPlayerRevisionChanged: refreshMediaLength()
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hasJobs: notifications.activeJobsCount > 0
    readonly property bool hasNotifications: notificationCount() > 0
    readonly property bool mediaActivityEnabled: Plasmoid.configuration.mediaActivityEnabled !== false
    // A player that exists but hasn't played for 30 s hands the island back to the idle face; anything that starts
    // playing takes it back at once (D-35). MediaIdle.js decides, the timer below only schedules the timeout.
    property bool mediaGraceExpired: false
    readonly property bool mediaShown: MediaIdle.shown(hasPlayer, isPlaying, mediaGraceExpired)

    function mediaIdleEvent(event) {
        const r = MediaIdle.reduce({ "expired": mediaGraceExpired }, event);
        mediaGraceExpired = r.expired;
        if (r.scheduleMs !== null) {
            mediaIdleTimer.interval = r.scheduleMs;
            mediaIdleTimer.restart();
        } else {
            mediaIdleTimer.stop();
        }
    }

    function syncMediaIdle() {
        mediaIdleEvent(!hasPlayer ? "gone" : isPlaying ? "playing" : "notPlaying");
    }

    onHasPlayerChanged: syncMediaIdle()
    onIsPlayingChanged: syncMediaIdle()

    Timer {
        id: mediaIdleTimer

        repeat: false
        onTriggered: root.mediaIdleEvent("timeout")
    }
    readonly property bool notificationActivityEnabled: Plasmoid.configuration.notificationActivityEnabled !== false
    readonly property bool jobActivityEnabled: Plasmoid.configuration.jobActivityEnabled !== false
    readonly property bool keyboardLayoutActivityEnabled: Plasmoid.configuration.keyboardLayoutActivityEnabled !== false
    readonly property bool notificationImagesEnabled: Plasmoid.configuration.notificationShowImages !== false
    readonly property int notificationBodyCharacters: Math.max(40, Math.min(1000, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationBodyCharacterLimit, 240))))
    readonly property int notificationBodyLines: Math.max(1, Math.min(6, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationBodyLineLimit, 3))))
    readonly property int notificationPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(Plasmoid.configuration.notificationPopupDurationSeconds, 4)) * 1000))
    // How long the presented notification stays up (D-33): the user's setting, shortened by the app's own timeout
    // (2 s floor) and at least 6 s when critical. One value drives both the popup timer and the lifetime timer.
    readonly property int noticeDurationMs: {
        const row = noticeRowFor(activeNoticeId);
        return NoticeDuration.effectiveDurationMs(
            rowValue(row, NotificationManager.Notifications.TimeoutRole, -1), notificationPopupDurationMs,
            rowValue(row, NotificationManager.Notifications.UrgencyRole, NotificationManager.Notifications.NormalUrgency));
    }
    readonly property int ongoingPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(Plasmoid.configuration.ongoingPopupDurationSeconds, 3)) * 1000))
    readonly property var keyboardLayoutNames: keyboardLayout.layoutsList.length > keyboardLayout.layout ? keyboardLayout.layoutsList[keyboardLayout.layout] : null
    readonly property string keyboardLayoutShortName: keyboardLayoutNames ? keyboardLayoutNames.shortName || "" : ""
    readonly property string keyboardLayoutDisplayName: keyboardLayoutNames ? keyboardLayoutNames.displayName || keyboardLayoutShortName : keyboardLayoutShortName
    readonly property string keyboardLayoutLongName: keyboardLayoutNames ? keyboardLayoutNames.longName || keyboardLayoutDisplayName : keyboardLayoutDisplayName
    readonly property int notificationUnreadCount: notifications.unreadNotificationsCount
    // True while the pointer is over a clickable notice popup (drives the whole-island highlight and the open glyph).
    // The playback position is only drawn by the compact media pill, the expanded media popup and the Control
    // Center's media card, so it is only polled while one of them can be seen.
    readonly property bool mediaPositionVisible: hasPlayer && isPlaying && !fullscreenCovering && (popupMode === "control" ? dialogVisible : islandOpen ? popupMode === "activity" && popupActivityMode() === "media" : !panelHidden && activityMode() === "media")
    onMediaPositionVisibleChanged: {
        // Refresh right away so the bar is current the moment it appears.
        if (mediaPositionVisible && player && player.updatePosition)
            player.updatePosition();
    }
    property bool noticeHovered: false
    // True while the pointer is over an activity popup (notice, media, job...), clickable or not. Together with the
    // dialog holding keyboard focus it freezes the popup's timers, which finish with the time left once the pointer
    // or focus is gone.
    property bool popupHovered: false
    readonly property bool holdPopupTimers: dialogVisible && islandOpen && popupMode === "activity" && (popupHovered || dialogActive)
    readonly property bool holdNoticeLifetime: holdPopupTimers && activityPopupMode === "notice"
    readonly property bool hasActivity: keyboardAnnouncementActive || jobActivityEnabled && hasJobs || mediaActivityEnabled && mediaShown || noticeActivityActive
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
    property int mediaPlayerRevision: 0
    property int notificationRevision: 0
    // Identity of the notification the island is currently presenting as a
    // temporary activity. History alone must not keep the activity alive.
    property var activeNoticeId: null
    property bool clearingNotifications: false
    readonly property bool noticeActivityActive: notificationActivityEnabled && noticeRowFor(activeNoticeId) >= 0
    property bool keyboardAnnouncementActive: false
    property int lastUnreadNotificationsCount: 0
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

    function rowValue(row, role, fallbackValue) {
        notificationRevision;
        if (row < 0 || notifications.count <= row)
            return fallbackValue;

        const value = notifications.data(notifications.index(row, 0), role);
        return value === undefined || value === null ? fallbackValue : value;
    }

    function firstRowOfType(type) {
        for (let i = 0; i < notifications.count; ++i) {
            if (rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType) === type)
                return i;

        }
        return -1;
    }

    function notificationRows(limit) {
        const out = [];
        const maxRows = Math.max(0, Math.round(Utils.finiteNumber(limit, 0)));
        for (let i = 0; i < notifications.count; ++i) {
            if (rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType) !== NotificationManager.Notifications.NotificationType)
                continue;

            out.push(i);
            if (maxRows > 0 && out.length >= maxRows)
                break;

        }
        return out;
    }

    function notificationCount() {
        return notificationRows(0).length;
    }

    function notificationAppName(row) {
        const appName = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.ApplicationNameRole, ""));
        if (appName.length > 0)
            return appName;

        const desktopEntry = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        return desktopEntry.length > 0 ? desktopEntry : i18n("Notification");
    }

    function notificationTitle(row) {
        const summary = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.SummaryRole, ""));
        return summary.length > 0 ? summary : notificationAppName(row);
    }

    function notificationBody(row) {
        return TextUtils.truncate(notificationPlainText(rowValue(row, NotificationManager.Notifications.BodyRole, "")), notificationBodyCharacters);
    }

    function notificationAppIcon(row) {
        const applicationIcon = rowValue(row, NotificationManager.Notifications.ApplicationIconNameRole, "");
        if (Utils.hasVisualValue(applicationIcon))
            return applicationIcon;

        const desktopEntry = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        return desktopEntry.length > 0 ? desktopEntry : "notifications";
    }

    function notificationMainIcon(row) {
        const icon = rowValue(row, NotificationManager.Notifications.IconNameRole, "");
        return Utils.hasVisualValue(icon) ? icon : notificationAppIcon(row);
    }

    function notificationMainImage(row) {
        const image = rowValue(row, NotificationManager.Notifications.ImageRole, null);
        if (Utils.hasVisualValue(image))
            return image;

        const urls = rowValue(row, NotificationManager.Notifications.UrlsRole, []);
        if (!urls || urls.length === undefined)
            return null;
        for (let i = 0; i < urls.length; ++i) {
            const candidate = String(urls[i] || "");
            const path = candidate.split(/[?#]/)[0].toLowerCase();
            if (/\.(avif|bmp|gif|heic|heif|jpe?g|png|svgz?|webp)$/.test(path))
                return urls[i];
        }
        return null;
    }

    function notificationHasMainImage(row) {
        return Utils.hasVisualValue(notificationMainImage(row));
    }

    function notificationIcon(row) {
        return notificationMainIcon(row);
    }

    function notificationAccent(row) {
        const urgency = notificationUrgency(row);
        if (urgency >= 2)
            return "#ff453a";
        if (urgency <= 0)
            return "#8f9099";
        return "#ff9f0a";
    }

    // Colour of the small urgency dot in the expanded notification. The model role holds KDE's
    // Notifications::Urgency enum (Low=1, Normal=2, Critical=4), not the D-Bus byte, and anything
    // unknown is shown as Normal (green), never as Critical. Visual only: priority uses notificationUrgency().
    function notificationUrgencyColor(row) {
        const raw = rowValue(row, NotificationManager.Notifications.UrgencyRole, NotificationManager.Notifications.NormalUrgency);
        switch (raw) {
        case NotificationManager.Notifications.LowUrgency:
            return "#6c6e78";
        case NotificationManager.Notifications.CriticalUrgency:
            return "#E66A65";
        default:
            return "#3ac255";
        }
    }

    // Creation time (ms since epoch) of a notification row, 0 when unknown. Display only.
    function notificationCreatedMs(row) {
        const created = rowValue(row, NotificationManager.Notifications.CreatedRole, null);
        const t = created && created.getTime ? created.getTime() : Number(created);
        return isFinite(t) && t > 0 ? t : 0;
    }

    function notificationUrgency(row) {
        return Utils.finiteNumber(rowValue(row, NotificationManager.Notifications.UrgencyRole, 1), 1);
    }

    function noticeRowFor(id) {
        if (id === null || id === undefined)
            return -1;
        const wanted = String(id);
        for (let i = 0; i < notifications.count; ++i) {
            if (rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType) !== NotificationManager.Notifications.NotificationType)
                continue;
            if (String(rowValue(i, NotificationManager.Notifications.IdRole, "")) === wanted)
                return i;
        }
        return -1;
    }

    function notificationLatestRow() {
        const tracked = noticeRowFor(activeNoticeId);
        if (tracked >= 0)
            return tracked;
        const rows = notificationRows(1);
        return rows.length > 0 ? rows[0] : -1;
    }

    // The model only exposes a limited window of history, so older entries can
    // slide in as rows are removed. Only recently created notifications count
    // as arrivals.
    function isFreshNotification(row) {
        if (clearingNotifications)
            return false;
        const created = rowValue(row, NotificationManager.Notifications.CreatedRole, null);
        if (!created)
            return true;
        const t = created.getTime ? created.getTime() : Number(created);
        return !isFinite(t) || Math.abs(Date.now() - t) < 15000;
    }

    // A newer notification arrived: present it and (re)start its lifetime.
    function noticeArrived(row) {
        if (row === undefined || row < 0)
            return ;
        activeNoticeId = rowValue(row, NotificationManager.Notifications.IdRole, null);
        if (activeNoticeId === null)
            return ;
        noticeLifetimeTimer.restart();
        bump("notice");
    }

    // Drop the notification activity without touching media, jobs or history.
    function dismissNoticeActivity(closePopup) {
        noticeLifetimeTimer.stop();
        const wasShowing = activeNoticeId !== null;
        activeNoticeId = null;
        if (wasShowing && closePopup && dialogVisible && popupMode === "activity" && activityPopupMode === "notice")
            closeIsland();
    }

    // Called after the model changes: if the presented notification was
    // removed (single dismissal, Clear All, expiry), dismiss its activity.
    function syncNoticeActivity() {
        if (activeNoticeId !== null && noticeRowFor(activeNoticeId) < 0)
            dismissNoticeActivity(true);
    }

    function notificationStatusText() {
        const count = notificationCount();
        if (count <= 0)
            return i18n("Quiet");
        if (count === 1)
            return i18n("1 notification");
        return i18np("%1 notification", "%1 notifications", count);
    }

    function notificationOverflowCount(limit) {
        return Math.max(0, notificationCount() - Math.max(0, Math.round(Utils.finiteNumber(limit, 0))));
    }

    // What a click on this notification would do (D-31). "none" rows are not clickable.
    function notificationOpenTarget(row) {
        const entry = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        const info = entry.length > 0 ? appLauncher.desktopEntryInfo[entry] : undefined;
        if (entry.length > 0 && info === undefined)
            appLauncher.lookupDesktopEntry(entry);

        return NotificationOpen.resolve({
            "expired": rowValue(row, NotificationManager.Notifications.ExpiredRole, false) === true,
            "hasDefaultAction": rowValue(row, NotificationManager.Notifications.HasDefaultActionRole, false) === true,
            "urls": rowValue(row, NotificationManager.Notifications.UrlsRole, []),
            "desktopEntry": entry,
            "desktopEntryLaunchable": info !== undefined && info.display === true
        });
    }

    function notificationClickable(row) {
        return notificationOpenTarget(row).kind !== "none";
    }

    // Click handlers pass a row index; resolve it to the notification id right away.
    function openNotification(row) {
        return openNotificationById(rowValue(row, NotificationManager.Notifications.IdRole, null));
    }

    // The row is looked up by id at click time, so a model change since render can't retarget the click.
    function openNotificationById(id) {
        const row = noticeRowFor(id);
        if (row < 0)
            return false;

        const target = notificationOpenTarget(row);
        if (target.kind === "none")
            return false;

        const idx = notifications.index(row, 0);
        if (target.kind === "action") {
            notifications.invokeDefaultAction(idx, NotificationManager.Notifications.Close);
        } else {
            if (target.kind === "url")
                Qt.openUrlExternally(target.target);
            else
                appLauncher.launch(target.target);
            if (rowValue(row, NotificationManager.Notifications.ClosableRole, true))
                notifications.close(idx);
        }
        // The model change also dismisses the activity; closing here covers the Control Center.
        if (dialogVisible)
            closeIsland();
        return true;
    }

    function activeRowFor(kind) {
        const mode = resolvedActivityMode(kind || "auto");
        if (mode === "notice") {
            const noticeRow = firstRowOfType(NotificationManager.Notifications.NotificationType);
            if (noticeRow >= 0)
                return noticeRow;
        }

        if (mode === "job") {
            const jobRow = firstRowOfType(NotificationManager.Notifications.JobType);
            if (jobRow >= 0)
                return jobRow;
        }

        const job = firstRowOfType(NotificationManager.Notifications.JobType);
        if (job >= 0)
            return job;

        const notice = firstRowOfType(NotificationManager.Notifications.NotificationType);
        return notice >= 0 ? notice : 0;
    }

    function activeRow() {
        return activeRowFor("auto");
    }

    function notificationPlainText(text) {
        return TextUtils.plainText(text);
    }

    function mediaText(value) {
        return String(value || "").replace(/\s+/g, " ").trim();
    }

    function mediaHasMetadata(playerLike) {
        if (!playerLike)
            return false;

        return mediaText(playerLike.track).length > 0 || mediaText(playerLike.artist).length > 0 || mediaText(playerLike.album).length > 0 || mediaText(playerLike.artUrl).length > 0 || Utils.finiteNumber(playerLike.length, 0) > 0;
    }

    function mediaIsBrowserish(playerLike) {
        if (!playerLike)
            return false;

        const name = (mediaText(playerLike.identity) + " " + mediaText(playerLike.desktopEntry)).toLowerCase();
        return name.indexOf("vivaldi") !== -1 || name.indexOf("chromium") !== -1 || name.indexOf("chrome") !== -1 || name.indexOf("firefox") !== -1 || name.indexOf("browser") !== -1;
    }

    function mediaPlayerScore(playerLike) {
        if (!playerLike)
            return -1;

        const status = playerLike.playbackStatus;
        const hasMetadata = mediaHasMetadata(playerLike);
        if (status === Mpris.PlaybackStatus.Stopped)
            return -1;

        if (status !== Mpris.PlaybackStatus.Playing && !hasMetadata)
            return -1;

        let score = 0;
        if (status === Mpris.PlaybackStatus.Playing)
            score += 1000;
        else if (status === Mpris.PlaybackStatus.Paused)
            score += 500;
        else
            score += 100;

        if (mediaText(playerLike.track).length > 0)
            score += 80;
        if (mediaText(playerLike.artist).length > 0)
            score += 45;
        if (mediaText(playerLike.album).length > 0)
            score += 20;
        if (mediaText(playerLike.artUrl).length > 0)
            score += 20;
        if (Utils.finiteNumber(playerLike.length, 0) > 0)
            score += 25;
        if (playerLike.canControl)
            score += 10;
        if (playerLike.canPlay || playerLike.canPause)
            score += 10;
        if (mediaIsBrowserish(playerLike) && !hasMetadata)
            score -= 400;

        return score;
    }

    function bestMediaPlayer() {
        mediaPlayerRevision;
        let best = null;
        let bestScore = -1;
        if (mediaPlayerInstantiator) {
            for (let i = 0; i < mediaPlayerInstantiator.count; ++i) {
                const candidate = mediaPlayerInstantiator.objectAt(i);
                const score = mediaPlayerScore(candidate);
                if (score > bestScore) {
                    best = candidate ? candidate.playerContainer : null;
                    bestScore = score;
                }
            }
        }

        const fallbackScore = mediaPlayerScore(rawPlayer);
        if (fallbackScore > bestScore) {
            best = rawPlayer;
            bestScore = fallbackScore;
        }

        return bestScore >= 0 ? best : null;
    }

    function mediaPrevious() {
        const current = player;
        if (current && current.canGoPrevious)
            current.Previous();
    }

    function mediaPlayPause() {
        const current = player;
        if (current && (current.canPlay || current.canPause))
            current.PlayPause();
    }

    function mediaNext() {
        const current = player;
        if (current && current.canGoNext)
            current.Next();
    }

    function formatMediaTime(value) {
        const seconds = Math.max(0, Math.floor(Utils.finiteNumber(value, 0) / 1000000));
        const minutes = Math.floor(seconds / 60);
        const remainder = seconds % 60;
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }

    function formatMediaProgress(position, length) {
        return formatMediaTime(position) + " / " + formatMediaTime(length);
    }

    function activeJobRow() {
        return firstRowOfType(NotificationManager.Notifications.JobType);
    }

    function jobDetails(row) {
        return rowValue(row, NotificationManager.Notifications.JobDetailsRole, null);
    }

    function jobTitle(row) {
        const details = jobDetails(row);
        const title = TextUtils.cleanText(details && details.summary ? details.summary : rowValue(row, NotificationManager.Notifications.SummaryRole, ""));
        return title.length > 0 ? title : i18n("Working");
    }

    function jobText(row) {
        const details = jobDetails(row);
        const text = TextUtils.cleanText(details && details.text ? details.text : rowValue(row, NotificationManager.Notifications.BodyRole, ""));
        if (text.length > 0)
            return text;
        const appName = TextUtils.cleanText(details && details.applicationName ? details.applicationName : rowValue(row, NotificationManager.Notifications.ApplicationNameRole, ""));
        return appName;
    }

    function jobIcon(row) {
        const details = jobDetails(row);
        const icon = details && details.applicationIconName ? details.applicationIconName : rowValue(row, NotificationManager.Notifications.ApplicationIconNameRole, "");
        if (Utils.hasVisualValue(icon))
            return icon;
        const desktopEntry = TextUtils.cleanText(details && details.desktopEntry ? details.desktopEntry : rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        return desktopEntry.length > 0 ? desktopEntry : "folder-download";
    }

    function jobState(row) {
        const details = jobDetails(row);
        if (details && details.state !== undefined)
            return details.state;
        return rowValue(row, NotificationManager.Notifications.JobStateRole, NotificationManager.Notifications.JobStateRunning);
    }

    function jobPercentage(row) {
        const details = jobDetails(row);
        const percentage = details && details.percentage !== undefined ? details.percentage : rowValue(row, NotificationManager.Notifications.PercentageRole, -1);
        return Math.max(-1, Math.min(100, Math.round(Utils.finiteNumber(percentage, -1))));
    }

    function jobSuspendable(row) {
        const details = jobDetails(row);
        return details && details.suspendable !== undefined ? details.suspendable : Boolean(rowValue(row, NotificationManager.Notifications.SuspendableRole, false));
    }

    function jobKillable(row) {
        const details = jobDetails(row);
        return details && details.killable !== undefined ? details.killable : Boolean(rowValue(row, NotificationManager.Notifications.KillableRole, false));
    }

    function jobIsSuspended(row) {
        return jobState(row) === NotificationManager.Notifications.JobStateSuspended;
    }

    function toggleJobSuspended(row) {
        if (row < 0 || row >= notifications.count || !jobSuspendable(row))
            return ;
        const idx = notifications.index(row, 0);
        if (jobIsSuspended(row))
            notifications.resumeJob(idx);
        else
            notifications.suspendJob(idx);
    }

    function cancelJob(row) {
        if (row < 0 || row >= notifications.count || !jobKillable(row))
            return ;
        notifications.killJob(notifications.index(row, 0));
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

    // Close every closable notification currently in the model window. Returns
    // how many were closed.
    function closeNotificationRows() {
        let closed = 0;
        for (let i = notifications.count - 1; i >= 0; --i) {
            if (rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType) !== NotificationManager.Notifications.NotificationType)
                continue;

            if (rowValue(i, NotificationManager.Notifications.ClosableRole, true)) {
                notifications.close(notifications.index(i, 0));
                ++closed;
            }
        }
        if (closed === 0)
            clearingNotifications = false;
        return closed;
    }

    // Clear All: the model exposes a limited window of history, so keep
    // closing until nothing closable is left, then drop the island activity.
    function clearNotifications() {
        clearingNotifications = true;
        clearNotificationsGuardTimer.restart();
        closeNotificationRows();
        dismissNoticeActivity(true);
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

    NotificationManager.Notifications {
        id: notifications

        limit: 8
        showNotifications: true
        showJobs: true
        // Keep Plasma popup history visible in Dynamic Island after the system
        // popup times out or is hidden. Closing it here still calls close().
        showExpired: true
        showDismissed: true
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
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
                active: root.noticeActivityActive
                priority: root.notificationUrgency(root.notificationLatestRow()) >= 2 ? 400 : 200
                title: root.notificationTitle(root.notificationLatestRow())
                subtitle: root.notificationBody(root.notificationLatestRow())
                artwork: root.notificationMainImage(root.notificationLatestRow())
                autoCloseMs: root.noticeDurationMs
                visualComponent: noticeVisualComponent
                compactComponent: notificationCompactComponent
                expandedComponent: notificationActivityPage
            },
            Activities.ActivityProvider {
                key: "media"
                active: root.mediaActivityEnabled && root.mediaShown
                priority: 100
                title: root.hasPlayer ? root.player.track || root.player.identity || "Media" : "Media"
                subtitle: root.hasPlayer ? root.player.artist || root.player.album || root.player.identity || "" : ""
                artwork: root.hasPlayer ? root.player.artUrl : ""
                progressVisible: root.hasPlayer && root.mediaLength > 0
                progressTo: Math.max(1, root.hasPlayer ? root.mediaLength : 1)
                progressValue: root.hasPlayer ? root.player.position : 0
                progressAccent: "#5ac8fa"
                mediaControlsVisible: root.hasPlayer
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

    Mpris.Mpris2Model {
        id: mprisModel

        onCurrentPlayerChanged: {
            root.mediaPlayerRevision++;
            root.bump("media");
        }
    }

    Instantiator {
        id: mediaPlayerInstantiator

        model: Mpris.MultiplexerModel {}
        onObjectAdded: root.mediaPlayerRevision++
        onObjectRemoved: root.mediaPlayerRevision++

        delegate: QtObject {
            readonly property var playerContainer: model.container
            readonly property int playbackStatus: model.playbackStatus
            readonly property string track: model.track || ""
            readonly property string artist: model.artist || ""
            readonly property string album: model.album || ""
            readonly property string artUrl: model.artUrl || ""
            readonly property real length: Utils.finiteNumber(model.length, 0)
            readonly property string identity: model.identity || ""
            readonly property string desktopEntry: model.desktopEntry || ""
            readonly property bool canControl: model.canControl || false
            readonly property bool canPlay: model.canPlay || false
            readonly property bool canPause: model.canPause || false

            onPlaybackStatusChanged: {
                root.mediaPlayerRevision++;
                root.bump("media");
            }
            onTrackChanged: {
                root.mediaPlayerRevision++;
                root.bump("media");
            }
            onArtistChanged: root.mediaPlayerRevision++
            onAlbumChanged: root.mediaPlayerRevision++
            onArtUrlChanged: root.mediaPlayerRevision++
            onLengthChanged: root.mediaPlayerRevision++
            onIdentityChanged: root.mediaPlayerRevision++
        }
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

    ControlLayout {
        id: controlLayoutService

        storedJson: String(Plasmoid.configuration.controlCenterLayoutJson || "")
        dragHost: dialogHost
        iconState: ({
            "wifiEnabled": enabledConnections.wirelessEnabled,
            "batteryCharging": batteryControl.pluggedIn,
            "powerProfileIcon": powerProfileIcon()
        })
        onSaveRequested: json => Plasmoid.configuration.controlCenterLayoutJson = json
    }

    AppLauncher {
        id: appLauncher

        runner: commands
        configuredCalendarApp: String(Plasmoid.configuration.calendarApp || "")
        forecastAvailable: weatherService.configured
        forecastUrl: weatherService.forecastUrl
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }

    Component.onCompleted: {
        root.syncMediaIdle();
        if (root.panelSyncWanted())
            panelStartTimer.start();
        controlLayoutService.ensureLayout();
        root.refreshSystemState();
        appLauncher.discoverCalendarApp();
        root.lastUnreadNotificationsCount = notifications.unreadNotificationsCount;
        root.lastActiveJobsCount = notifications.activeJobsCount;
    }

    Connections {
        function onPlaybackStatusChanged() {
            root.bump("media");
        }

        function onTrackChanged() {
            root.bump("media");
        }

        target: root.player
    }

    Connections {
        function onRowsInserted(parent, first, last) {
            root.notificationRevision++;
            let freshNoticeRow = -1;
            let hasInsertedJob = false;
            for (let row = first; row <= last; ++row) {
                const type = root.rowValue(row, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType);
                if (type === NotificationManager.Notifications.JobType)
                    hasInsertedJob = true;
                else if (type === NotificationManager.Notifications.NotificationType && freshNoticeRow < 0 && root.isFreshNotification(row))
                    freshNoticeRow = row;
            }
            if (hasInsertedJob)
                root.bump("job");
            else if (freshNoticeRow >= 0)
                root.noticeArrived(freshNoticeRow);
        }

        function onRowsRemoved(parent, first, last) {
            root.notificationRevision++;
            root.syncNoticeActivity();
            if (root.clearingNotifications)
                Qt.callLater(root.closeNotificationRows);
        }

        function onDataChanged(topLeft, bottomRight, roles) {
            root.notificationRevision++;
            root.syncNoticeActivity();
        }

        function onModelReset() {
            root.notificationRevision++;
            root.syncNoticeActivity();
        }

        function onActiveJobsCountChanged() {
            const count = notifications.activeJobsCount;
            if (count > root.lastActiveJobsCount)
                root.bump("job");
            root.lastActiveJobsCount = count;
        }

        function onUnreadNotificationsCountChanged() {
            const count = notifications.unreadNotificationsCount;
            // Do not treat unread-count growth as an arrival: Plasma marks a
            // notification unread when its own popup expires, which would
            // re-show an already presented notification. Arrivals are handled
            // by onRowsInserted.
            root.lastUnreadNotificationsCount = count;
        }

        target: notifications
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

    // Safety net so a Clear All can never leave arrivals suppressed.
    Timer {
        id: clearNotificationsGuardTimer

        interval: 700
        repeat: false
        onTriggered: root.clearingNotifications = false
    }

    PausableTimer {
        id: noticeLifetimeTimer

        duration: root.noticeDurationMs
        hold: root.holdNoticeLifetime
        onTriggered: root.dismissNoticeActivity(activityPopupTimer.running)
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
            if (root.clickButton === Qt.MiddleButton && root.player)
                root.mediaPlayPause();
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

    Timer {
        id: positionTimer

        interval: 1000
        running: root.mediaPositionVisible
        repeat: true
        onTriggered: {
            if (root.player && root.player.updatePosition)
                root.player.updatePosition();

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
            artworkSource: root.hasPlayer ? root.player.artUrl : ""
            cornerRadius: root.notchShape ? Math.round(Math.min(width, height) * 0.3) : Math.min(width, height) / 2 // notch: rounded square like expanded; pill: circle
            mode: "media"
            progress: root.activityProgressValue("media") / Math.max(1, root.activityProgressTo("media"))
            playing: root.isPlaying
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
            source: root.notificationAppIcon(root.notificationLatestRow())
            fallbackSource: "notifications"
            fallbackColor: root.notificationAccent(root.notificationLatestRow())
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
                    if (root.player && root.player.changeVolume)
                        root.player.changeVolume(wheel.angleDelta.y > 0 ? 0.04 : -0.04, true);
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

                    readonly property int noticeRow: root.popupMode === "activity" && root.popupActivityMode() === "notice" ? root.notificationLatestRow() : -1
                    readonly property bool noticeClickable: noticeRow >= 0 && root.notificationClickable(noticeRow)

                    anchors.fill: parent
                    enabled: root.islandOpen && noticeClickable
                    // Single click opens immediately; the notice popup has no double-click behaviour.
                    onClicked: root.openNotificationById(root.rowValue(noticeRow, NotificationManager.Notifications.IdRole, null))
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
                    playing: root.popupActivityMode() === "media" ? root.isPlaying : root.popupActivityMode() === "job" ? !root.jobIsSuspended(root.activeJobRow()) : false
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
                    enabled: root.player && root.player.canGoPrevious
                    onClicked: root.mediaPrevious()
                }

                IslandButton {
                    iconName: root.isPlaying ? "media-playback-pause" : "media-playback-start"
                    compact: true
                    emphasized: true
                    tooltipText: root.isPlaying ? i18n("Pause") : i18n("Play")
                    enabled: root.player && (root.player.canPlay || root.player.canPause)
                    onClicked: root.mediaPlayPause()
                }

                IslandButton {
                    iconName: "media-skip-forward"
                    compact: true
                    tooltipText: i18n("Next")
                    enabled: root.player && root.player.canGoNext
                    onClicked: root.mediaNext()
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
            notificationsSource: notifications
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
