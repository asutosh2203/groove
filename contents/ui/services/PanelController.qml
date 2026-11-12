pragma ComponentBehavior: Bound

import QtQuick
import org.kde.taskmanager as TaskManager
import "../logic/FullscreenState.js" as FullscreenState
import "../logic/PanelPlan.js" as PanelPlan

// The island's relationship with the panel it sits in and the screen it is on: keeping the panel attached (Notch) or
// restored (Pill) through Plasma's scripting service, finding the screen under a point, and noticing a fullscreen window
// that covers the island. The decisions are pure (PanelPlan.js, FullscreenState.js); this object runs the scripting
// command, holds the phase and the timers, and reports what to remember through signals, so it never touches the widget
// config itself. If anything is uncertain the panel is left untouched.
Item {
    id: controller

    required property var runner
    // The panel this applet sits in and the applet's own id, as the scripting service knows them.
    property int containmentId: 0
    property int appletId: 0
    property rect screenGeometry: Qt.rect(0, 0, 0, 0)
    // Notch mode attaches the panel (not floating, thickness = notchThickness); Pill mode restores it.
    property bool notch: false
    property int notchThickness: 40
    // The panel's settings from before the first change (widget config); only count for the panel they came from.
    property int originalPanelId: 0
    property int originalFloating: -1
    property int originalThickness: 0

    // The first change is about to be made: remember these.
    signal originalsCaptured(int panelId, int floating, int thickness)
    // The panel is back to what it was: forget them.
    signal originalsCleared()

    property int phase: 0 // 0 idle, 1 reading, 2 applying
    property bool pending: false
    property int attempts: 0
    property string action: ""
    // A fullscreen window on top of the island's screen hides it, so decorative loops and the position poll stop.
    // Event-driven: the task model reports windows as they open, close, minimize or change fullscreen.
    property bool fullscreenCovering: false
    readonly property var originals: ({
        "panelId": originalPanelId,
        "floating": originalFloating,
        "thickness": originalThickness
    })

    function syncWanted() {
        return PanelPlan.syncWanted(notch, originalPanelId);
    }

    function sync() {
        if (!syncWanted())
            return ;
        if (phase !== 0) {
            pending = true;
            return ;
        }
        if (!(containmentId > 0))
            return ;
        phase = 1;
        runner.run(PanelPlan.command(containmentId, appletId, null, 0), onOutput);
        watchdog.restart();
    }

    function apply(applyAction, floating, thickness) {
        action = applyAction;
        phase = 2;
        runner.run(PanelPlan.command(containmentId, appletId, floating, thickness), onOutput);
        watchdog.restart();
    }

    // The scripting command's output; anything that is not a panel reply is ignored.
    function onOutput(stdout) {
        if (PanelPlan.isReply(stdout))
            handleReply(String(stdout).trim());
    }

    function handleReply(out) {
        watchdog.stop();
        const reply = PanelPlan.parseReply(out);
        const handledPhase = phase;
        phase = 0;
        attempts = 0;
        if (!reply.ok) {
            console.warn("Dynamic Island: could not identify its panel, leaving it untouched");
        } else if (handledPhase === 1) {
            const plan = PanelPlan.decide(reply, originals, notch, notchThickness);
            if (plan.warn)
                console.warn("Dynamic Island: " + plan.warn);
            if (plan.capture)
                originalsCaptured(plan.capture.panelId, plan.capture.floating, plan.capture.thickness);
            if (plan.clear)
                originalsCleared();
            if (plan.apply)
                apply(plan.apply.action, plan.apply.floating, plan.apply.thickness);
        } else if (handledPhase === 2) {
            const result = PanelPlan.evaluateApply(reply, action, originals, notchThickness);
            if (result.warn)
                console.warn("Dynamic Island: " + result.warn);
            if (result.clear)
                originalsCleared();
        }
        if (phase === 0 && pending) {
            pending = false;
            Qt.callLater(sync);
        }
    }

    function screenForPoint(pointX, pointY) {
        const index = PanelPlan.nearestScreen(Application.screens, pointX, pointY);
        return index < 0 ? null : Application.screens[index];
    }

    function updateFullscreen() {
        const tasks = [];
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.index(i, 0);
            tasks.push({
                "isWindow": tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow),
                "fullScreen": tasksModel.data(idx, TaskManager.AbstractTasksModel.IsFullScreen),
                "minimized": tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized)
            });
        }
        fullscreenCovering = FullscreenState.covering(tasks);
    }

    onNotchChanged: Qt.callLater(sync)
    Component.onCompleted: {
        if (syncWanted())
            startTimer.start();

    }

    // Startup sync is delayed until the shell's scripting service is up, and retried a couple of times if a request
    // never answers.
    Timer {
        id: startTimer

        interval: 2500
        repeat: false
        onTriggered: controller.sync()
    }

    Timer {
        id: watchdog

        interval: 8000
        repeat: false
        onTriggered: {
            controller.phase = 0;
            if (controller.attempts++ < 2)
                startTimer.restart();
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: tasksModel

        filterByVirtualDesktop: true
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByScreen: true
        screenGeometry: controller.screenGeometry
        groupMode: TaskManager.TasksModel.GroupDisabled
        onCountChanged: controller.updateFullscreen()
        onDataChanged: controller.updateFullscreen()
        Component.onCompleted: controller.updateFullscreen()
    }
}
