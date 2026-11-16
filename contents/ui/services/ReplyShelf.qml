pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../logic/GlowMotion.js" as Glow
import "../logic/ReplyShelf.js" as Shelf

// The inline reply shelf's state and motion (D-43). Decisions live in ReplyShelf.js; this holds the state and the
// timers, and talks to the notification model only through `notifications`.
Item {
    id: shelf

    required property var notifications
    // The popup shows a replyable notification and the island can grow downward.
    property bool eligible: false
    property bool hovering: false
    property bool fieldFocused: false
    property string draft: ""
    property var shelfState: Shelf.initial()
    property bool dwellSpent: false
    readonly property bool animationsOff: Glow.animationsOff(Kirigami.Units.longDuration)
    readonly property string phase: shelfState.phase
    readonly property bool isOpen: Shelf.isOpen(shelfState)
    readonly property bool holding: Shelf.holdsLifetime(shelfState, fieldFocused, draft)
    readonly property string error: shelfState.error
    property real progress: 0

    signal opening()
    signal cleared()
    signal popupCloseRequested()

    function dispatch(type, message) {
        shelfState = Shelf.reduce(shelfState, type, message);
    }

    function open() {
        if (!eligible || isOpen)
            return ;

        dispatch("open");
        opening();
    }

    function close() {
        dispatch("close");
        if (!isOpen)
            clear();
    }

    function clear() {
        draft = "";
        fieldFocused = false;
        cleared();
    }

    function escapePressed() {
        if (Shelf.escapeAction(shelfState) === "closeShelf")
            close();
        else
            popupCloseRequested();
    }

    function edited() {
        dispatch("edit");
    }

    function send() {
        if (!Shelf.canSend(draft))
            return ;

        dispatch("send");
        if (notifications.replyById(notifications.activeNoticeId, draft.trim())) {
            dispatch("sent");
            clear();
            notifications.dismissNotice(true);
        } else {
            dispatch("failed", "gone");
        }
    }

    onIsOpenChanged: {
        progressAnimation.stop();
        if (animationsOff) {
            progress = isOpen ? 1 : 0;
            return ;
        }
        progressAnimation.duration = isOpen ? 550 : 260;
        progressAnimation.easing.type = isOpen ? Easing.OutBack : Easing.OutCubic;
        progressAnimation.to = isOpen ? 1 : 0;
        progressAnimation.start();
    }
    onEligibleChanged: {
        if (!eligible) {
            shelfState = Shelf.initial();
            clear();
        }
    }
    onHoveringChanged: {
        if (!hovering)
            dwellSpent = false;
        if (!hovering && Shelf.leaveAction(shelfState, draft, fieldFocused) === "close")
            close();
    }
    onProgressChanged: {
        if (phase === "opening" && progress >= 0.999)
            dispatch("opened");
    }

    // Open springs past the end; close eases out with no overshoot, so nothing dips before the window shrinks. Started
    // explicitly: a Behavior reads the old direction when it picks its duration and easing.
    NumberAnimation {
        id: progressAnimation

        target: shelf
        property: "progress"
        easing.overshoot: 1.5
    }

    // A new notification replaces the one being replied to.
    Connections {
        function onActiveNoticeIdChanged() {
            shelf.dwellSpent = false;
            shelf.shelfState = Shelf.initial();
            shelf.clear();
        }

        target: shelf.notifications
    }

    // The dwell never takes keyboard focus: a click on the field does.
    Timer {
        interval: Shelf.dwellMs
        running: Shelf.shouldDwell(shelf.shelfState, shelf.hovering, shelf.eligible, shelf.dwellSpent)
        onTriggered: {
            shelf.dwellSpent = true;
            shelf.open();
        }
    }
}
