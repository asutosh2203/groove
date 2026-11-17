pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager
import "../logic/Agents.js" as Agents

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
    // session id -> true when a window of it can be raised (Agents.findWindow, ignoring the title tie-break).
    property var raisable: ({})

    // A session appeared.
    signal agentStarted()

    function byId(id) {
        return sessions.find(s => s.id === id) ?? null;
    }

    function setSnapshot(json) {
        const next = Agents.order(Agents.parse(json));
        const known = new Set(sessions.map(s => s.id));
        const grew = next.some(s => !known.has(s.id));
        sessions = next;
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
        for (const s of sessions)
            next[s.id] = Agents.findWindow(s, tasks) >= 0;
        raisable = next;
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

        active: host.hasAgents
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
