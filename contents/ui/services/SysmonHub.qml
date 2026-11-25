pragma ComponentBehavior: Bound

import QtQuick
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.workspace.dbus as DBus
import "../controlcenter/Tokens.js" as T
import "../logic/Subscribers.js" as Subscribers
import "../logic/Sysmon.js" as Sysmon

// The System Monitor's data for one island (D-65). It samples exactly the sensors the placed widgets show, from KDE's sensor
// framework, keeps the last two minutes in memory (the OS keeps only counters) and posts the hot alerts. It lives here, not in
// the widget views, because a view exists only while its page shows. All decisions are Sysmon.js's. With no widget placed no
// Sensor object exists and nothing ticks (P9): one Timer, 1 s while a view shows, 5 s otherwise, stopped while the screen is
// locked, when the Sensors are disabled as well.
Item {
    id: hub

    // [{ pid, kinds, alerts }] of every placement in the active presets (or the open draft).
    required property var subscriptions
    // True while the preset editor is open: the settings form needs to know which sensors exist.
    required property bool inspecting
    // Posts a notification: post(summary, body, icon, onId(id)).
    required property var notifier
    required property var strings

    readonly property var cfg: ({
            "windowMs": T.sysmonWindowSec * 1000,
            "gapFactor": T.sysmonGapFactor,
            "gapMs": T.sysmonGapFactor * T.sysmonHiddenTick,
            "coolBy": T.sysmonCoolBy,
            "hot": { "load": T.sysmonHotLoad, "cpuTemp": T.sysmonHotCpuTemp, "gpuTemp": T.sysmonHotGpuTemp },
            "sustainMs": { "load": T.sysmonAlertSustainLoadSec * 1000, "ram": T.sysmonAlertSustainRamSec * 1000, "temp": T.sysmonAlertSustainTempSec * 1000 },
            "cooldownMs": T.sysmonAlertCooldownSec * 1000,
            "readyMs": T.sysmonReadySec * 1000,
            "rateFloor": T.sysmonRateFloor
        })
    // The ids to sample; replaced only when the list really changes, so reopening the editor does not recreate every Sensor.
    property var wantedIds: []
    readonly property var alertKinds: Sysmon.alertKinds(hub.subscriptions)
    readonly property bool hasSubs: hub.subscriptions.length > 0
    // The views showing now (Subscribers pattern); only the count matters here, the grace does not.
    property var viewers: Subscribers.create()
    readonly property bool viewing: hub.viewers.count > 0
    readonly property int tick: hub.viewing ? T.sysmonVisibleTick : T.sysmonHiddenTick
    property bool locked: false
    // The ids the daemon lists, or null while unknown.
    property var available: null
    property var rings: ({})
    property var latest: ({})
    property var texts: ({})
    property var healths: ({})
    property var born: ({})
    property var alertStates: ({})
    property double warmUntil: 0
    // Whether the sampling clock runs (nothing of either with no widget placed).
    readonly property bool sampling: clock.running
    // Bumped on every sample so bindings re-read.
    property int revision: 0

    // How many Sensor objects exist (a binding on Instantiator.count goes stale in 6.12).
    function sensorTotal() {
        return sensors.count;
    }

    function holdView() {
        hub.viewers = Subscribers.add(hub.viewers);
    }

    function releaseView() {
        hub.viewers = Subscribers.remove(hub.viewers, Date.now());
    }

    // One kind's face: { state, reason, hero, suffix, hot, companion }.
    function face(kind) {
        if (hub.revision < 0)
            return null;
        const s = Sysmon.kindState(kind, hub.available, hub.healths, hub.latest);
        const d = s.state === "ready" ? Sysmon.display(kind, hub.latest) : null;
        return {
            "state": s.state,
            "reason": s.reason,
            "hero": d ? d.hero : "",
            "suffix": d ? d.suffix : "",
            "hot": s.state === "ready" && (hub.alertStates[kind]?.hot ?? false),
            "companion": s.state === "ready" ? Sysmon.companion(kind, hub.latest, hub.texts) : null
        };
    }

    function plot(kind, w, h) {
        if (hub.revision < 0)
            return null;
        return Sysmon.plot(kind, hub.rings, hub.latest, Date.now(), hub.cfg, w, h);
    }

    function sample() {
        const now = Date.now();
        if (now < hub.warmUntil)
            return;
        const rings = Object.assign({}, hub.rings);
        const latest = Object.assign({}, hub.latest);
        const texts = Object.assign({}, hub.texts);
        const healths = {};
        for (let i = 0; i < sensors.count; ++i) {
            const s = sensors.objectAt(i) as Sensors.Sensor;
            if (!s)
                continue;
            const id = s.sensorId;
            healths[id] = Sysmon.health(Sysmon.statusName(s.status), now - (hub.born[id] ?? now), hub.cfg.readyMs);
            if (healths[id] !== "ready")
                continue;
            if (typeof s.value === "number") {
                latest[id] = s.value;
                rings[id] = Sysmon.push(rings[id], now, s.value, hub.tick, hub.cfg.windowMs);
            } else if (s.value !== undefined)
                texts[id] = String(s.value);
        }
        hub.rings = rings;
        hub.latest = latest;
        hub.texts = texts;
        hub.healths = healths;
        hub.evaluate(now);
        hub.revision++;
    }

    // Hot level and alerts for each shown kind, from this sample.
    function evaluate(now) {
        const states = {};
        for (const kind of Sysmon.wantedKinds(hub.subscriptions)) {
            // A sensor that is gone or silent keeps its last value in `latest`; that stale value must not count toward an alert.
            if (Sysmon.kindState(kind, hub.available, hub.healths, hub.latest).state !== "ready")
                continue;
            const r = Sysmon.reading(kind, hub.latest);
            const thr = Sysmon.thresholdFor(kind, hub.cfg.hot);
            if (r === null || thr === null)
                continue;
            const step = Sysmon.alertStep(hub.alertStates[kind] ?? Sysmon.initialAlert(), r.pct, thr, hub.alertKinds.indexOf(kind) >= 0, now, hub.cfg, Sysmon.sustainFor(kind, hub.cfg.sustainMs));
            states[kind] = step.state;
            if (step.fire)
                hub.notifier.post(hub.strings.sysmonAlert(kind, Sysmon.alertValue(kind, hub.latest), step.fire.seconds), "", "utilities-system-monitor", null);
        }
        hub.alertStates = states;
    }

    // A placement that went away takes its history with it.
    function prune() {
        const keep = {};
        hub.wantedIds.forEach(id => keep[id] = true);
        for (const name of ["rings", "latest", "texts", "healths", "born"]) {
            const next = {};
            Object.keys(hub[name]).filter(id => keep[id]).forEach(id => next[id] = hub[name][id]);
            hub[name] = next;
        }
        hub.revision++;
    }

    function setLocked(value) {
        if (value === hub.locked)
            return ;
        hub.locked = value;
        if (!value)
            hub.warmUntil = Date.now() + T.sysmonWarmMs;
    }

    function askLocked() {
        const reply = DBus.SessionBus.asyncCall({
            "service": "org.freedesktop.ScreenSaver",
            "path": "/ScreenSaver",
            "iface": "org.freedesktop.ScreenSaver",
            "member": "GetActive"
        });
        reply.finished.connect(() => {
            if (!reply.isError)
                hub.setLocked(reply.value === true);
        });
    }

    // The daemon's sensor ids, listed without subscribing to any.
    function walk(model, parent, ids) {
        for (let r = 0; r < model.rowCount(parent); ++r) {
            const ix = model.index(r, 0, parent);
            const id = model.data(ix, Sensors.SensorTreeModel.SensorId);
            if (id)
                ids[id] = true;
            if (model.hasChildren(ix)) {
                if (model.canFetchMore(ix))
                    model.fetchMore(ix);
                hub.walk(model, ix, ids);
            }
        }
    }

    function refreshAvailable(model) {
        const ids = {};
        hub.walk(model, model.index(-1, -1), ids);
        hub.available = Object.keys(ids).length > 0 ? ids : null;
    }

    function syncWanted() {
        const next = Sysmon.wanted(hub.subscriptions);
        if (JSON.stringify(next) !== JSON.stringify(hub.wantedIds))
            hub.wantedIds = next;
    }

    onSubscriptionsChanged: hub.syncWanted()
    onWantedIdsChanged: hub.prune()
    onHasSubsChanged: {
        if (hub.hasSubs)
            hub.askLocked();
    }
    Component.onCompleted: {
        hub.syncWanted();
        if (hub.hasSubs)
            hub.askLocked();
    }

    Timer {
        id: clock

        interval: hub.tick
        repeat: true
        running: hub.wantedIds.length > 0 && !hub.locked
        onTriggered: hub.sample()
    }

    DBus.SignalWatcher {
        enabled: hub.hasSubs
        busType: DBus.BusType.Session
        service: "org.freedesktop.ScreenSaver"
        path: "/ScreenSaver"
        iface: "org.freedesktop.ScreenSaver"

        function dbusActiveChanged(active: bool): void {
            hub.setLocked(active);
        }
    }

    // Only the sensors a placed widget shows exist as objects.
    Instantiator {
        id: sensors

        model: hub.wantedIds
        onObjectAdded: (index, object) => {
            const sensor = object as Sensors.Sensor;
            hub.born[sensor.sensorId] = Date.now();
        }

        delegate: Sensors.Sensor {
            required property string modelData

            sensorId: modelData
            enabled: !hub.locked
            updateRateLimit: hub.tick
        }
    }

    Loader {
        id: tree

        active: hub.hasSubs || hub.inspecting
        onActiveChanged: {
            if (!tree.active)
                hub.available = null;
        }

        sourceComponent: Sensors.SensorTreeModel {
            id: model

            Component.onCompleted: hub.refreshAvailable(model)
            onRowsInserted: Qt.callLater(hub.refreshAvailable, model)
            onRowsRemoved: Qt.callLater(hub.refreshAvailable, model)
            onModelReset: Qt.callLater(hub.refreshAvailable, model)
        }
    }
}
