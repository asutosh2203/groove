pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "services"
import "logic/KdeConnectState.js" as KdeConnectState
import "logic/Utils.js" as Utils
import "controlcenter/Tokens.js" as T
import "logic/ActivityResolver.js" as ActivityResolver
import "logic/DeckPlan.js" as DeckPlan
import "logic/ClockFormat.js" as ClockFormat
import "logic/WeatherForecast.js" as WeatherForecast
import "activities" as Activities
import "shell"
import "weather"

PlasmoidItem {
    id: root

    // The widget config as an untyped object: qmllint cannot know the keys of a KConfig map.
    readonly property var settings: Plasmoid.configuration
    readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge].includes(Plasmoid.location)
    readonly property bool verticalPanel: [PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge].includes(Plasmoid.location)
    readonly property bool mediaActivityEnabled: root.settings.mediaActivityEnabled !== false
    readonly property bool notificationActivityEnabled: root.settings.notificationActivityEnabled !== false
    readonly property bool glowExpandedEnabled: root.settings.glowExpandedEnabled !== false
    readonly property bool glowControlCenterEnabled: root.settings.glowControlCenterEnabled !== false
    readonly property bool jobActivityEnabled: root.settings.jobActivityEnabled !== false
    readonly property bool keyboardLayoutActivityEnabled: root.settings.keyboardLayoutActivityEnabled !== false
    readonly property bool notificationImagesEnabled: root.settings.notificationShowImages !== false
    readonly property int notificationBodyCharacters: Math.max(40, Math.min(1000, Math.round(Utils.finiteNumber(root.settings.notificationBodyCharacterLimit, 240))))
    readonly property int notificationBodyLines: Math.max(1, Math.min(6, Math.round(Utils.finiteNumber(root.settings.notificationBodyLineLimit, 3))))
    readonly property int notificationPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(root.settings.notificationPopupDurationSeconds, 4)) * 1000))
    readonly property int ongoingPopupDurationMs: Math.max(2000, Math.min(15000, Math.round(Utils.finiteNumber(root.settings.ongoingPopupDurationSeconds, 3)) * 1000))
    // True while the pointer is over a clickable notice popup (drives the whole-island highlight and the open glyph).
    // The playback position is only drawn by the compact media pill, the expanded media popup and the Control
    // Center's media card, so it is only polled while one of them can be seen.
    readonly property bool mediaPositionVisible: mediaService.hasPlayer && mediaService.isPlaying && !panelController.fullscreenCovering && (popupMode === "deck" ? dialogVisible : islandOpen ? popupMode === "activity" && popupActivityMode() === "media" : !panelHidden && activityMode() === "media")
    property bool noticeHovered: false
    // True while the pointer is over an activity popup (notice, media, job...), clickable or not. Together with the
    // dialog holding keyboard focus it freezes the popup's timers, which finish with the time left once the pointer
    // or focus is gone.
    property bool popupHovered: false
    readonly property bool holdPopupTimers: dialogVisible && islandOpen && popupMode === "activity" && (popupHovered || dialogActive && !resumeDeck || replyShelfService.holding)
    readonly property bool holdNoticeLifetime: holdPopupTimers && activityPopupMode === "notice"
    readonly property bool hasActivity: systemControls.announcementActive || jobActivityEnabled && jobService.hasJobs || agentService.active || mediaActivityEnabled && mediaService.shown || notificationService.activityActive
    // Fixed allocation: the panel never resizes for visual transitions. The
    // visible shape is drawn inside whatever slot the panel actually gives us.
    // The visible body is islandBodyWidth in both shapes; the notch's concave ears flare shoulder px outside it, so its
    // item (and the panel allocation) is wider by two shoulders.
    readonly property int islandBodyWidth: 180
    readonly property real shapeEars: notchShape ? 2 * notchShoulder : 0
    readonly property int islandWidth: islandBodyWidth + shapeEars
    readonly property int islandHeight: 40
    readonly property bool notchShape: root.settings.shellShape === "notch"
    // Notch mode attaches the containing panel to the screen edge (not floating,
    // thickness = shell height) and Pill mode restores the panel's saved settings.
    readonly property int notchPanelThickness: islandHeight
    readonly property real notchShoulder: 8
    readonly property real notchBottomRadius: Math.round(Math.min(realIslandHeight, islandHeight) * 0.35)
    readonly property real compactArtworkSize: Math.max(18, realIslandHeight - 8) - (notchShape ? 2 : 0) // notch: 2px extra bottom inset
    readonly property real realIslandWidth: compactRepresentationItem && compactRepresentationItem.width > 0 ? compactRepresentationItem.width : islandWidth
    readonly property real realIslandHeight: compactRepresentationItem && compactRepresentationItem.height > 0 ? compactRepresentationItem.height : islandHeight
    readonly property int mediaPopupWidth: 340
    // The silhouette's size (D-51): the viewed deck page, or a pop-in's fixed size. The window itself is popupWidth x
    // popupHeight: with the deck it is pre-sized once (D-43) and never changes while visible.
    readonly property int pageWidth: popupMode === "deck" ? deckState.sizeOf(deckState.current).w : (popupActivityMode() === "media" || popupActivityMode() === "notice" ? mediaPopupWidth : 294)
    readonly property int mediaPopupHeight: 120
    readonly property int pageBaseHeight: popupMode === "deck" ? deckState.sizeOf(deckState.current).h : (popupActivityMode() === "media" || popupActivityMode() === "notice" ? mediaPopupHeight : 104)
    property bool deckWindowActive: false
    readonly property int popupWidth: (deckWindowActive ? deckState.windowSize.w : pageWidth) + shapeEars
    readonly property bool ccShowing: popupMode === "deck" && (presetEditor.active ? presetEditor.view === "gear" : deckState.current === "control")
    // D-43: a replyable notice gets a window with room for the shelf from before it first shows, and keeps it until the
    // popup is hidden: resizing a visible window shows one stretched frame on Wayland.
    readonly property int replyShelfHeight: 30
    readonly property bool replyCapableNotice: islandExpandsDown && notificationService.canReply(notificationService.activeNoticeId)
    property bool replyWindowReserved: false
    readonly property int popupHeight: deckWindowActive ? deckState.windowSize.h : pageBaseHeight + (replyWindowReserved && popupMode === "activity" ? replyShelfHeight + 8 : 0)
    readonly property bool replyEligible: islandExpandsDown && dialogVisible && islandOpen && popupMode === "activity" && popupActivityMode() === "notice" && notificationService.canReply(notificationService.activeNoticeId)
    readonly property int popupRadius: ccShowing ? 28 : 26
    readonly property bool islandExpandsUp: Plasmoid.location === PlasmaCore.Types.BottomEdge
    readonly property bool islandExpandsDown: Plasmoid.location === PlasmaCore.Types.TopEdge
    property bool dialogVisible: false
    onDialogVisibleChanged: {
        if (!dialogVisible)
            deckWindowActive = false;
        if (!dialogVisible && !replyCapableNotice)
            replyWindowReserved = false;
    }
    onReplyCapableNoticeChanged: {
        if (replyCapableNotice)
            replyWindowReserved = true;
        else if (!dialogVisible)
            replyWindowReserved = false;
    }
    property bool islandOpen: false
    property bool panelHidden: false
    property bool popupAcceptsFocus: false
    property bool popupMenuOpen: false
    property bool dialogActive: false
    property real popupCollapsedX: (popupWidth - realIslandWidth) / 2
    property real popupCollapsedY: islandExpandsUp ? popupHeight - realIslandHeight : islandExpandsDown ? 0 : (popupHeight - realIslandHeight) / 2
    property string popupMode: "deck"
    // A pop-in (notice, keyboard layout) opened over the deck: when it ends the deck comes back on the same page. The
    // deck's own keyboard focus does not freeze the pop-in's timers; hovering it still does.
    property bool resumeDeck: false
    property string activityPopupMode: "auto"
    property int clickButton: Qt.NoButton


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

        const popupScreen = panelController.screenForPoint(collapsedX + realIslandWidth / 2, collapsedY + realIslandHeight / 2);
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
            deckWindowActive = mode === "deck";
            resumeDeck = false;
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

        presetEditor.suspend();

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

    // A pop-in ran its course (timer or dismissed): back to the deck page underneath, else close.
    function endPopIn() {
        if (resumeDeck && dialogVisible && popupMode === "activity") {
            resumeDeck = false;
            popupMode = "deck";
            return ;
        }
        closeIsland();
    }

    // A click on the window's transparent area or a bare surface: with unsaved edits it asks before closing (D-56).
    function closeFromClick() {
        if (presetEditor.active && presetEditor.dirty)
            presetEditor.promptOpen = true;
        else
            closeIsland();
    }

    function focusIslandDialog() {
        popupAcceptsFocus = true;
        if (islandDialog.requestActivate)
            islandDialog.requestActivate();
    }

    function bump(kind) {
        const requestedProvider = kind && kind !== "auto" ? activityController.providerByKey(kind) : null;
        const nextMode = activityController.keyFor(kind || "auto");
        const decision = ActivityResolver.bumpDecision({
            "requestedExists": requestedProvider !== null,
            "requestedActive": requestedProvider !== null && requestedProvider.active,
            "hasActivity": hasActivity,
            "suppressed": DeckPlan.suppressesBump(nextMode, dialogVisible && popupMode === "deck"),
            "activityPopupOpen": islandOpen && popupMode === "activity",
            "popupTimerRunning": activityPopupTimer.running,
            "nextPriority": activityController.priorityFor(nextMode),
            "shownPriority": activityController.priorityFor(activityPopupMode)
        });
        if (decision === "extend")
            activityPopupTimer.restart();
        else if (decision === "show")
            showActivityPopup(true, nextMode);
    }

    function showActivityPopup(autoClose, kind) {
        activityPopupMode = activityController.keyFor(kind || "auto");
        const overDeck = dialogVisible && deckWindowActive && popupMode === "deck";
        openIsland("activity", autoClose);
        if (overDeck)
            resumeDeck = true;
    }

    // Opens the deck on the page the entry rules choose: "click" or "double" (the Control Center).
    function showDeck(intent) {
        systemControls.cancelAnnouncement();
        root.refreshSystemState();
        controlLayoutService.ensureLayout();
        deckState.open(intent);
        presetEditor.resumeIfKept();
        openIsland("deck", false);
        Qt.callLater(root.focusIslandDialog);
    }

    // A click on a job tile or row: show its destination in the file manager and close the deck (D-31); a job with no
    // usable destination does nothing.
    function openJob(row) {
        const target = jobService.openTarget(row);
        if (target.kind !== "show")
            return ;
        appLauncher.showInFileManager(target.url);
        closeIsland();
    }

    // A click on an agent tile: raise the window that hosts the session and close the deck (D-31, D-57).
    function openAgent(sid) {
        if (agentService.raise(sid))
            closeIsland();
    }

    function jobClickable(row) {
        return jobService.openTarget(row).kind === "show";
    }

    // A click on the media card's artwork or title: raise the player's window, else ask the player to raise itself over
    // MPRIS. The exact browser tab is not guaranteed.
    function raisePlayer() {
        const player = mediaService.player;
        if (player) {
            const entry = String(player.desktopEntry || "");
            appLauncher.raise(entry.length > 0 ? [entry] : [], () => {
                if (mediaService.player && mediaService.player.canRaise)
                    mediaService.player.Raise();
            });
        }
        closeIsland();
    }

    function showControlCenter() {
        showDeck("double");
    }

    function toggleActivityPopup(autoClose) {
        if (islandOpen && popupMode === "activity") {
            closeIsland();
            return ;
        }
        showActivityPopup(autoClose, "auto");
    }

    function toggleControlCenter() {
        if (ccShowing && islandOpen) {
            closeIsland();
            return ;
        }
        showControlCenter();
    }

    function notificationStatusText() {
        return translations.notificationStatus(notificationService.count());
    }

    function activeRowFor(kind) {
        return ActivityResolver.rowFor(activityController.keyFor(kind || "auto"), notificationService.firstRowOfType(NotificationManager.Notifications.NotificationType), notificationService.firstRowOfType(NotificationManager.Notifications.JobType));
    }

    function activeRow() {
        return activeRowFor("auto");
    }

    function jobTitle(row) {
        return translations.jobTitle(jobService.titleText(row), jobService.fileCount(row));
    }

    function jobSubtitle(row) {
        return translations.jobSubtitle(jobService.destination(row), jobService.text(row));
    }

    function jobMetaText(row) {
        return translations.jobMeta(jobService.meta(row));
    }

    function primaryTextFor(kind) {
        return activityController.titleFor(kind, translations.idleTitle);
    }

    function primaryText() {
        return primaryTextFor("auto");
    }

    function secondaryTextFor(kind) {
        return activityController.subtitleFor(kind, translations.idleSubtitle);
    }

    function secondaryText() {
        return secondaryTextFor("auto");
    }

    function activityMode() {
        return activityController.currentKey;
    }

    function popupActivityMode() {
        return popupMode === "activity" ? activityController.keyFor(activityPopupMode) : activityMode();
    }

    // Faint 1px top highlight on the Pill surfaces (the Notch has none); set to 0 to disable.
    readonly property real rimLight: 0.12
    property string idleHoverTitle: ""
    property string idleHoverText: ""
    property string idleClickTarget: ""
    readonly property alias weather: weatherService
    readonly property alias launcher: appLauncher
    readonly property bool reduceMotion: Kirigami.Units.longDuration <= 1
    readonly property alias layoutService: controlLayoutService
    readonly property alias editor: presetEditor
    readonly property alias media: mediaService
    readonly property alias notifications: notificationService
    readonly property alias replyShelf: replyShelfService
    readonly property alias jobs: jobService
    readonly property alias connectivity: connectivityService
    readonly property alias system: systemControls
    readonly property alias strings: translations
    readonly property alias activities: activityController
    // The item the popup content is laid out in (the dialog's main item).
    readonly property alias hostItem: dialogHost

    WeatherService {
        id: weatherService
    }


    function refreshSystemState() {
        systemControls.refreshAccount();
        connectivityService.refreshAll();
    }

    function wifiTitle() {
        return translations.wifiTitle(connectivityService.connections.wirelessHwEnabled, connectivityService.connections.wirelessEnabled);
    }

    function bluetoothSummary() {
        return translations.bluetoothSummary(connectivityService.bluetoothSummary());
    }

    function bluetoothDetail() {
        return translations.bluetoothDetail(connectivityService.bluetoothDetail());
    }

    function kdeConnectSummary() {
        const devices = connectivityService.kdeConnectDevices(0);
        return translations.kdeConnectSummary(KdeConnectState.summaryKind(devices), KdeConnectState.connectedCount(devices));
    }

    function powerProfileTitle() {
        return translations.profileTitle(systemControls.profileKind());
    }

    function batteryText() {
        return translations.batteryText(systemControls.batteryKind(), systemControls.battery.percent);
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
    Plasmoid.title: translations.appTitle
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

    // The Live page's inputs (D-52). Only the cheap count is always live; the job details are built while the deck shows.
    readonly property bool liveMedia: mediaActivityEnabled && mediaService.shown
    readonly property int liveCount: (liveMedia ? 1 : 0) + agentService.sessions.length + (jobActivityEnabled ? jobService.activeCount : 0)
    readonly property alias deck: deckState
    readonly property alias agents: agentService

    // The widget registry and the presets (D-54); the host reaches them as app.widgets, and the clock service as app.clock.
    readonly property alias widgets: presetStore
    readonly property alias clock: clockService
    readonly property bool use24Hour: ClockFormat.is24Hour(Qt.locale().timeFormat(Locale.ShortFormat))

    PresetStore {
        id: presetStore

        devPresets: String(root.settings.devPresets || "")
        storedPresets: String(root.settings.presets || "")
    }

    ClockService {
        id: clockService

        localLabel: WeatherForecast.cityName(weatherService.locationName)
    }

    readonly property alias weatherHub: weatherHub

    WeatherHub {
        id: weatherHub

        island: weatherService
        locations: presetStore.weatherLocations.concat(presetEditor.weatherLocations)
    }

    // A widget's click (D-54): run its action through the host and close the deck (D-31). Widgets never run commands.
    function runWidgetAction(action) {
        if (action.type === "url" && /^https?:\/\//.test(String(action.value)))
            Qt.openUrlExternally(action.value);
        else if (action.type === "app")
            appLauncher.launch(String(action.value));
        else if (action.type === "calendar")
            appLauncher.openCalendar();
        else
            return ;
        closeIsland();
    }

    DeckState {
        id: deckState

        liveCount: root.liveCount
        deckVisible: root.dialogVisible && root.popupMode === "deck"
        liveMedia: root.liveMedia
        liveMediaKind: mediaService.kind
        liveAgents: agentService.sessions
        liveJobs: root.jobActivityEnabled && root.dialogVisible && root.popupMode === "deck" ? jobService.runningRows() : []
        presets: presetStore.presets
        editing: presetEditor.active
        editSize: presetEditor.active ? DeckPlan.editSize(presetEditor.view, presetEditor.pageType, deckState.geom) : null
        geom: ({
            "cellW": T.deckCellW,
            "cellH": T.deckCellH,
            "padding": T.deckPadding,
            "capsuleExtra": T.deckCapsuleGap + T.deckCapsuleHeight,
            "capsuleW": 2 * T.deckCapsulePad + 5 * T.deckCapsuleItem,
            "liveHeaderH": T.liveHeaderHeight,
            "liveRowH": T.liveRowHeight,
            "liveGap": T.liveGap,
            "liveMediaGap": T.liveMediaGap,
            "liveTileH": T.liveTileHeight,
            "controlW": T.controlWidth,
            "controlH": T.controlHeight,
            "controlEditW": T.controlEditWidth,
            "controlEditH": T.controlEditHeight,
            "editInset": T.editInset,
            "editBar": T.editBar,
            "editChips": T.editChips,
            "editGap": T.editGap,
            "editSidebar": T.editSidebar,
            "editSidebarMinH": T.editSidebarMinH,
            "editHint": T.editHint,
            "editOutlinePad": T.editOutlinePad,
            "editZoom": T.editZoom
        })
    }

    PresetEditor {
        id: presetEditor

        storedPresets: String(root.settings.presets || "")
        devPresets: String(root.settings.devPresets || "")
        registry: presetStore.registry
        layout: controlLayoutService
        onSaveRequested: json => root.settings.presets = json
    }

    Activities.ActivityController {
        id: activityController

        providers: [
            Activities.ActivityProvider {
                key: "keyboard"
                active: systemControls.announcementActive
                priority: ActivityResolver.priority.keyboard
                title: systemControls.layoutLongName
                subtitle: systemControls.layoutDisplayName
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: keyboardVisualComponent
                expandedComponent: keyboardExpandedComponent
            },
            Activities.ActivityProvider {
                key: "agent"
                active: agentService.active
                priority: ActivityResolver.priority.job
                title: agentService.primary?.project ?? ""
                subtitle: agentService.primary ? translations.agentAction(agentService.primary.action, agentService.primary.target) : ""
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: agentVisualComponent
                compactComponent: agentCompactComponent
                expandedComponent: agentExpandedComponent
            },
            Activities.ActivityProvider {
                key: "job"
                active: root.jobActivityEnabled && jobService.hasJobs
                priority: ActivityResolver.priority.job
                title: root.jobTitle(jobService.activeRow())
                subtitle: jobService.text(jobService.activeRow())
                progressVisible: jobService.percentage(jobService.activeRow()) >= 0
                progressTo: 100
                progressValue: Math.max(0, jobService.percentage(jobService.activeRow()))
                progressAccent: T.fill
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: jobVisualComponent
                compactComponent: jobCompactComponent
                expandedComponent: jobExpandedComponent
            },
            Activities.ActivityProvider {
                key: "notice"
                active: notificationService.activityActive
                priority: ActivityResolver.noticePriority(notificationService.urgencyKind(notificationService.latestRow()))
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
                priority: ActivityResolver.priority.media
                title: mediaService.card.title
                subtitle: mediaService.card.subtitle
                artwork: mediaService.hasPlayer ? mediaService.player.artUrl : ""
                progressVisible: mediaService.hasPlayer && mediaService.length > 0
                progressTo: Math.max(1, mediaService.hasPlayer ? mediaService.length : 1)
                progressValue: mediaService.hasPlayer ? mediaService.player.position : 0
                progressAccent: T.fillSoft
                mediaControlsVisible: mediaService.hasPlayer
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: mediaVisualComponent
                compactComponent: musicCompactComponent
                expandedComponent: musicExpandedComponent
            },
            Activities.ActivityProvider {
                key: "idle"
                active: true
                priority: ActivityResolver.priority.idle
                title: translations.idleTitle
                subtitle: translations.idleSubtitle
                autoCloseMs: root.ongoingPopupDurationMs
                visualComponent: idleVisualComponent
                expandedComponent: activityPage
            }
        ]
    }

    CommandRunner {
        id: commands
    }

    ReplyShelf {
        id: replyShelfService

        notifications: notificationService
        eligible: root.replyEligible
        hovering: root.popupHovered
        onPopupCloseRequested: root.closeIsland()
    }

    NotificationService {
        id: notificationService

        launcher: appLauncher
        activityEnabled: root.notificationActivityEnabled
        bodyCharacters: root.notificationBodyCharacters
        popupDurationMs: root.notificationPopupDurationMs
        fallbackAppName: translations.notificationFallback
        holdLifetime: root.holdNoticeLifetime
        popupTimerRunning: activityPopupTimer.running
        onNoticeShown: root.bump("notice")
        onJobArrived: root.bump("job")
        onDismissed: (closePopup, wasShowing) => {
            if (wasShowing && closePopup && root.dialogVisible && root.popupMode === "activity" && root.activityPopupMode === "notice")
                root.endPopIn();
        }
        onOpened: {
            if (root.dialogVisible)
                root.closeIsland();
        }
    }

    Strings {
        id: translations
    }

    PanelController {
        id: panelController

        runner: commands
        containmentId: Plasmoid.containment ? Plasmoid.containment.id : 0
        appletId: Plasmoid.id
        screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
        notch: root.notchShape
        notchThickness: root.notchPanelThickness
        originalPanelId: root.settings.panelOrigPanelId
        originalFloating: root.settings.panelOrigFloating
        originalThickness: root.settings.panelOrigThickness
        onOriginalsCaptured: (panelId, floating, thickness) => {
            root.settings.panelOrigPanelId = panelId;
            root.settings.panelOrigFloating = floating;
            root.settings.panelOrigThickness = thickness;
        }
        onOriginalsCleared: {
            root.settings.panelOrigPanelId = 0;
            root.settings.panelOrigFloating = -1;
            root.settings.panelOrigThickness = 0;
        }
    }

    SystemControls {
        id: systemControls

        runner: commands
        announceEnabled: root.keyboardLayoutActivityEnabled
        announcementMs: root.ongoingPopupDurationMs + 420
        onActionRun: root.closeIsland()
        onLayoutAnnounced: root.bump("keyboard")
    }

    ConnectivityService {
        id: connectivityService

        runner: commands
        polling: root.dialogVisible && root.ccShowing
    }

    AgentService {
        id: agentService

        deckVisible: root.dialogVisible && root.popupMode === "deck"
    }

    JobService {
        id: jobService

        notifications: notificationService
        onJobStarted: root.bump("job")
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
            "wifiEnabled": connectivityService.connections.wirelessEnabled,
            "batteryCharging": systemControls.battery.pluggedIn,
            "powerProfileIcon": systemControls.profileIcon()
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
        controlLayoutService.ensureLayout();
        root.refreshSystemState();
        appLauncher.discoverCalendarApp();
    }

    // Shared low-rate clock for every decorative loop (weather icon, AudioBars); idle unless something holds a lease.
    readonly property var decorClock: decorClockItem

    DecorClock {
        id: decorClockItem

        paused: panelController.fullscreenCovering
    }


    PausableTimer {
        id: activityPopupTimer

        duration: activityController.autoCloseMsFor(root.activityPopupMode)
        hold: root.holdPopupTimers
        onTriggered: {
            if (root.popupMode === "activity")
                root.endPopIn();

        }
    }

    Timer {
        id: closeDialogTimer

        interval: 360
        repeat: false
        onTriggered: {
            if (!root.islandOpen) {
                root.dialogVisible = false;
                root.panelHidden = false;
                if (systemControls.announcementActive)
                    systemControls.cancelAnnouncement();

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

    // A click is decided after the double-click window, so a double click always wins.
    function scheduleClick(intervalMs) {
        clickTimer.interval = intervalMs;
        clickTimer.restart();
    }

    function cancelClick() {
        clickTimer.stop();
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
            else if (root.liveCount > 0 && ["notice", "keyboard"].indexOf(activityController.currentKey) < 0)
                root.showDeck("click");
            else if (root.hasActivity) {
                root.showActivityPopup(false);
                Qt.callLater(root.focusIslandDialog);
            } else if (root.idleClickTarget === "time") {
                appLauncher.openCalendar();
            } else if (root.idleClickTarget === "weather") {
                appLauncher.openForecast();
            } else {
                root.showDeck("click");
            }
        }
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
            const shouldClose = root.dialogActive && root.dialogVisible && root.islandOpen && !root.popupMenuOpen && !replyShelfService.holding;
            root.dialogActive = false;
            if (shouldClose)
                root.closeIsland();
        }
        onWidthChanged: root.positionIslandDialog()
        onHeightChanged: {
            if (!root.islandExpandsDown)
                root.positionIslandDialog();
        }

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

        MediaVisual {
            app: root
        }
    }

    Component {
        id: agentVisualComponent

        AgentVisual {
            app: root
        }
    }

    Component {
        id: agentCompactComponent

        Activities.AgentCompact {
            app: root
        }
    }

    Component {
        id: agentExpandedComponent

        AgentTile {
            app: root
            sid: agentService.primary?.id ?? ""
        }
    }

    Component {
        id: jobVisualComponent

        JobVisual {
            app: root
        }
    }

    Component {
        id: keyboardVisualComponent

        KeyboardVisual {
            app: root
        }
    }

    Component {
        id: noticeVisualComponent

        NoticeVisual {
            app: root
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

        IslandCompact {
            app: root
        }
    }

    Component {
        id: emptyFullRepresentation

        EmptyRepresentation {
            app: root
        }
    }

    Component {
        id: popupComponent

        PopupContent {
            app: root
            controlPage: controlCenterPage
        }
    }

    Component {
        id: activityPage

        ActivityPage {
            app: root
        }
    }

    Component {
        id: controlModuleCardDelegate

        ControlCenterCard {
            app: root
        }
    }

    Component {
        id: controlCenterPage

        ControlCenterPage {
            app: root
            cardDelegate: controlModuleCardDelegate
        }
    }
}
