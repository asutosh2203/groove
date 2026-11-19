pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents
import "../logic/ClaudeWidget.js" as Claude

// Coding-agent sessions (D-57), read from the per-user aggregator (integrations/claude-code). Nothing runs while its bus
// name is absent: the watchers are event-driven, there is no polling, and the task model loads only while a session exists.
Item {
    id: host

    readonly property string busName: "io.github.asutosh2203.Kove.Agents"
    readonly property string busPath: "/io/github/asutosh2203/Kove/Agents"
    readonly property string busIface: "io.github.asutosh2203.Kove.Agents1"

    // The aggregator is on the bus.
    readonly property bool available: watcher.registered
    // Ordered by Agents.order: waiting, working, done.
    property var sessions: []
    readonly property bool hasAgents: sessions.length > 0
    // Sessions that are running or waiting, not finished and lingering: what the closed capsule shows.
    readonly property var primary: sessions.find(s => s.state !== "done") ?? null
    readonly property bool active: primary !== null
    // For the Claude Code widget (D-60), all in memory and gone with plasmashell. The limit windows survive snapshots that lack
    // them (usage is account-wide); sawLimits is what tells a subscriber from an API-key setup; spend is sid -> cost.
    property var usage: ({})
    property bool sawLimits: false
    property var spend: ({})
    // Finished sessions, newest first (Claude.remember), with the keys to raise their window.
    property var recent: []
    // Which two sessions the Claude 2x1 shows (Claude.assign). It lives here so it survives the page being left.
    property var rowSlots: ({ "slots": [null, null], "waitSince": ({}) })
    // session id -> true when a window of it can be raised (Agents.findWindow, ignoring the title tie-break).
    property var raisable: ({})
    // session id -> the display name of the app hosting it ("Code"), for the tile's subtitle.
    property var hostNames: ({})

    // The deck is on screen (set by main): the only time a seconds clock is drawn.
    property bool deckVisible: false
    // The one clock behind every agent time. It runs only while a session works: every second while the deck shows a
    // moving seconds clock, every 5 s while a countdown moves the closed capsule's bar, otherwise once a minute (P9, D-58).
    property real nowMs: Date.now()
    readonly property bool secondsClock: deckVisible && sessions.some(s => Agents.needsSeconds(s, nowMs))
    readonly property bool countdownMoving: sessions.some(s => Agents.counting(s, nowMs))
    onDeckVisibleChanged: nowMs = Date.now()

    // A session appeared.
    signal agentStarted()

    function byId(id) {
        return sessions.find(s => s.id === id) ?? recent.find(s => s.id === id) ?? null;
    }

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function track(json, next) {
        const windows = Agents.parseUsage(json);
        if (Object.keys(windows).length > 0) {
            const merged = Claude.mergeUsage(usage, windows);
            if (!same(merged, usage))
                usage = merged;
            sawLimits = true;
        }
        spend = Claude.trackSpend(spend, next);
        const kept = Claude.remember(recent, next);
        if (!same(kept, recent))
            recent = kept;
        const placed = Claude.assign(rowSlots, next, kept);
        if (!same(placed, rowSlots))
            rowSlots = placed;
    }

    function setSnapshot(json) {
        nowMs = Date.now();
        const next = Agents.order(Agents.parse(json));
        const known = new Set(sessions.map(s => s.id));
        const grew = next.some(s => !known.has(s.id));
        sessions = next;
        track(json, next);
        refresh();
        if (grew)
            agentStarted();
    }

    function fetch() {
        DBus.SessionBus.asyncCall({
            "service": busName,
            "path": busPath,
            "iface": busIface,
            "member": "List"
        }, reply => host.setSnapshot(reply.value.value), () => {});
    }

    function windows() {
        const model = tasksLoader.item as TaskManager.TasksModel;
        const out = [];
        for (let i = 0; model && i < model.rowCount(); ++i) {
            const idx = model.index(i, 0);
            const last = model.data(idx, TaskManager.AbstractTasksModel.LastActivated);
            out.push({
                "pid": model.data(idx, TaskManager.AbstractTasksModel.AppPid),
                "appId": model.data(idx, TaskManager.AbstractTasksModel.AppId),
                "launcherUrl": model.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon),
                "title": model.data(idx, Qt.DisplayRole),
                "appName": model.data(idx, TaskManager.AbstractTasksModel.AppName),
                "isWindow": model.data(idx, TaskManager.AbstractTasksModel.IsWindow),
                "lastActivated": last ? last.getTime() : 0
            });
        }
        return out;
    }

    // Recomputes which sessions have a window. Only on a new snapshot or a window opening or closing: titles change too
    // often to listen to, and they only choose between windows already found.
    function refresh() {
        const tasks = windows();
        const next = {};
        const names = {};
        for (const s of sessions.concat(recent)) {
            const row = Agents.findWindow(s, tasks);
            next[s.id] = row >= 0;
            names[s.id] = row >= 0 ? String(tasks[row].appName || "") : "";
        }
        raisable = next;
        hostNames = names;
    }

    // Raises exactly the window that hosts the session (D-32: through the task model). False when there is none.
    function raise(id) {
        const s = byId(id);
        const model = tasksLoader.item as TaskManager.TasksModel;
        const row = s && model ? Agents.findWindow(s, windows()) : -1;
        if (row < 0)
            return false;
        model.requestActivate(model.index(row, 0));
        return true;
    }

    onAvailableChanged: {
        if (available)
            fetch();
        else
            setSnapshot("");
    }
    Component.onCompleted: {
        if (available)
            fetch();
    }

    Timer {
        interval: host.secondsClock ? T.secondTick : host.countdownMoving ? T.countdownTick : T.minuteTick
        repeat: true
        running: host.sessions.some(s => s.state === "working")
        onTriggered: host.nowMs = Date.now()
    }

    DBus.DBusServiceWatcher {
        id: watcher

        busType: DBus.BusType.Session
        watchedService: host.busName
    }

    DBus.SignalWatcher {
        enabled: host.available
        busType: DBus.BusType.Session
        service: host.busName
        path: host.busPath
        iface: host.busIface

        function dbusChanged(json: string): void {
            host.setSnapshot(json);
        }

        function dbusRaiseRequested(id: string): void {
            host.raise(id);
        }
    }

    Loader {
        id: tasksLoader

        active: host.hasAgents || host.recent.length > 0
        sourceComponent: TaskManager.TasksModel {
            filterByVirtualDesktop: false
            filterByScreen: false
            filterByActivity: false
            groupMode: TaskManager.TasksModel.GroupDisabled
            onCountChanged: host.refresh()
        }
        onLoaded: host.refresh()
    }
}
