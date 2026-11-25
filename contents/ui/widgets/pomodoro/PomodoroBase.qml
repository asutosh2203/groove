pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/PomodoroEngine.js" as Engine

// What every Pomodoro view shares (D-64): the placement's timer from the service, the words the face shows, and the
// seconds hold. A view exists only while its page shows, so it holds the 1 Hz clock exactly while mm:ss is visible.
Widgets.WidgetView {
    id: base

    readonly property var hub: base.services.timer ?? null
    readonly property var snap: base.hub ? base.hub.info(base.pid) : null
    readonly property var s: base.strings
    readonly property bool ready: base.snap?.status === "ready"
    readonly property bool running: base.snap?.status === "running"
    readonly property bool paused: base.snap?.status === "paused"
    readonly property bool ended: base.snap?.status === "ended"
    readonly property bool plain: base.snap?.plain ?? false
    readonly property bool tall: base.boxHeight >= T.widgetTallRoom
    readonly property int cols: base.span === "4x1" ? 4 : base.span === "2x1" ? 2 : 1
    // The left block is the 1x1 cell: a span-wide box splits into cells the way the host's grid does.
    readonly property real cellWidth: (base.boxWidth - T.gap * (base.cols - 1)) / base.cols

    widgetState: base.snap ? "ready" : "loading"

    readonly property string label: !base.snap || !base.s ? "" : base.ready ? (base.plain ? base.s.pomodoroTimerReady : base.s.pomodoroReady) : base.s.pomodoroPhase(base.ended ? base.snap.endedKind : base.snap.kind, base.plain)
    readonly property string hero: !base.snap ? "" : base.ended ? "0:00" : Engine.mmss(base.snap.remainingMs)
    readonly property string detail: {
        if (!base.snap || !base.s)
            return "";
        if (base.ready)
            return base.s.pomodoroReadyDetail(base.snap.rounds, base.snap.focusMinutes, base.snap.breakMinutes);
        if (base.ended)
            return base.snap.cycleOver ? base.s.pomodoroDoneCycle : base.s.pomodoroNextIs(base.snap.next.kind) + " · ▶";
        return base.plain ? base.s.pomodoroPlainOf(base.snap.focusMinutes) : base.s.pomodoroRound(base.snap.round, base.snap.rounds);
    }
    // Hovering the detail for a moment says what comes next.
    readonly property string peek: !base.snap || !base.s || base.ready || base.plain || base.ended ? "" : base.s.pomodoroNext(base.snap.next)
    // The extra line a taller box has room for.
    readonly property string extra: {
        if (!base.snap || !base.s || !base.tall)
            return "";
        if (base.snap.done > 0 && !base.plain && base.snap.next && base.snap.next.kind === "focus" && !base.ready)
            return base.s.pomodoroNextRound("focus", base.snap.next.round, base.snap.rounds);
        return base.snap.done > 0 ? base.s.pomodoroDone(base.snap.done) : "";
    }

    function ensure() {
        // A host that draws a timer without its widget settings (the Live tile) hands none over; the widget view owns them.
        if (base.hub && base.pid.length > 0 && base.settings.focus !== undefined)
            base.hub.ensure(base.pid, base.settings);
    }

    // The host injects `services` after the view loads, so the hold is taken when the hub arrives, not at completion.
    property var heldHub: null

    function hold() {
        if (base.hub === base.heldHub)
            return ;
        base.drop();
        base.heldHub = base.hub;
        if (base.heldHub)
            base.heldHub.holdSeconds();
    }

    function drop() {
        if (base.heldHub)
            base.heldHub.releaseSeconds();
        base.heldHub = null;
    }

    onHubChanged: {
        base.hold();
        base.ensure();
    }
    onSettingsChanged: base.ensure()
    onPidChanged: base.ensure()
    Component.onCompleted: {
        base.ensure();
        base.hold();
    }
    Component.onDestruction: base.drop()
}
