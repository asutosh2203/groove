pragma ComponentBehavior: Bound

import QtQuick
import "../logic/PomodoroDnd.js" as Dnd
import "../controlcenter/Tokens.js" as T
import "../logic/PomodoroEngine.js" as Engine

// The Pomodoro timers of one island (D-64), one per widget placement (keyed by its pid). They live here, not in the widget
// views, because a view exists only while its page shows and a focus must keep running behind it. All decisions are the pure
// engine's (deadlines, never a decremented counter) and the pure DND rules; this object holds the state, runs the clocks and
// does what they ask. Nothing ticks when no timer is running (P9): the one-shot at the nearest deadline and a 5 s coarse
// clock run only while something runs, and a 1 s clock only while a view that shows seconds exists.
Item {
    id: hub

    // Plasma's Do Not Disturb: { untilMs (null when off), setUntil(ms), clear() }.
    required property var dnd
    // Posts a notification: post(summary, body, icon, onId(id)).
    required property var notifier
    required property var strings
    // The pids of the placements in the saved presets; a timer whose placement is gone is dropped.
    property var livePids: []

    // A timer started from the alert's Start button, a tile or a view; the island opens nothing itself.
    signal started(string pid)

    property var timers: ({})
    property var alertIds: ({})
    property var dndState: Dnd.idle()
    // Bumped on every change so bindings re-read; nowMs is the clock the views compute from.
    property int revision: 0
    property double nowMs: Date.now()
    property int secondHolds: 0
    // The clocks run only while something runs, and the 1 s one only while a view that shows seconds exists (P9).
    readonly property bool ticking: hub.anyRunning && hub.secondHolds > 0
    readonly property bool anyRunning: hub.revision >= 0 && Object.keys(hub.timers).some(pid => hub.timers[pid].state.status === "running")
    // The one the closed capsule and the Live glyph speak for.
    readonly property var lead: hub.revision >= 0 ? Engine.lead(hub.entries()) : null
    readonly property var capsule: hub.lead ? Engine.capsule(hub.lead.state, hub.timers[hub.lead.pid].cfg, hub.nowMs) : null
    readonly property bool active: hub.capsule !== null
    // Live items ({ pid, status }): every timer that has started, waiting ones first.({ pid, status }).
    readonly property var liveTimers: hub.revision >= 0 ? Engine.order(hub.entries()).filter(t => t.state.status !== "ready").map(t => ({ "pid": t.pid, "status": t.state.status })) : []

    function entries() {
        return Object.keys(hub.timers).map(pid => ({ "pid": pid, "state": hub.timers[pid].state }));
    }

    function has(pid) {
        return hub.timers[pid] !== undefined;
    }

    // Called by a view or tile for its placement. A ready timer follows the settings at once; one in progress keeps its
    // own until it is reset, so editing a number cannot move a running deadline. The Do Not Disturb switch applies at once.
    function ensure(pid, settings) {
        const cfg = Engine.config(settings);
        const entry = hub.timers[pid];
        let dndChanged = false;
        if (!entry)
            hub.timers[pid] = { "cfg": cfg, "next": cfg, "state": Engine.initial(0) };
        else {
            if (JSON.stringify(entry.next) === JSON.stringify(cfg))
                return;
            entry.next = cfg;
            if (entry.state.status === "ready")
                entry.cfg = cfg;
            else if (entry.cfg.dnd !== cfg.dnd) {
                entry.cfg = Object.assign({}, entry.cfg, { "dnd": cfg.dnd });
                dndChanged = true;
            }
        }
        hub.revision++;
        if (dndChanged)
            hub.reconcile(null);
    }

    function info(pid) {
        const entry = hub.timers[pid];
        return hub.revision >= 0 && entry ? Engine.snapshot(entry.state, entry.cfg, hub.nowMs) : null;
    }

    function phases(pid) {
        return hub.timers[pid] ? Engine.phases(hub.timers[pid].cfg) : [];
    }

    function holdSeconds() {
        hub.secondHolds++;
        hub.nowMs = Date.now();
    }

    function releaseSeconds() {
        hub.secondHolds = Math.max(0, hub.secondHolds - 1);
    }

    function toggle(pid) {
        hub.change(pid, entry => Engine.toggle(entry.state, entry.cfg, Date.now()));
    }

    function play(pid) {
        hub.change(pid, entry => Engine.play(entry.state, entry.cfg, Date.now()));
    }

    function skip(pid) {
        hub.change(pid, entry => Engine.skip(entry.state));
    }

    function reset(pid) {
        hub.change(pid, entry => {
            entry.cfg = entry.next;
            return Engine.reset(entry.state);
        });
    }

    // The Start button of the phase-end notification: starts the timer whose alert this is.
    function startFromAlert(notificationId) {
        const pid = hub.pidForAlert(notificationId);
        if (pid.length > 0)
            hub.play(pid);
        return pid;
    }

    // Reads the revision so a pop-in already on screen gets its Start button once the id arrives.
    function pidForAlert(notificationId) {
        if (hub.revision < 0)
            return "";
        return Object.keys(hub.alertIds).find(pid => hub.alertIds[pid] === notificationId) ?? "";
    }

    function isAlert(notificationId) {
        return hub.pidForAlert(notificationId).length > 0;
    }

    // Applies one transition. DND ends before the alert is posted (PomodoroDnd), so the alert is never silenced.
    function change(pid, fn) {
        const entry = hub.timers[pid];
        if (!entry)
            return;
        const before = entry.state.status;
        entry.state = fn(entry);
        hub.nowMs = Date.now();
        if (entry.state.status === "running" && before !== "running")
            hub.started(pid);
        if (entry.state.status !== "ended" || before === "ended")
            delete hub.alertIds[pid];
        hub.revision++;
        hub.reconcile(null);
    }

    function focusEnd() {
        let latest = 0;
        for (const pid of Object.keys(hub.timers)) {
            const entry = hub.timers[pid];
            if (entry.cfg.dnd && entry.state.status === "running" && Engine.current(entry.state, entry.cfg).kind === "focus")
                latest = Math.max(latest, entry.state.endsAt);
        }
        return latest;
    }

    // Brings Plasma's DND in line with the running focus phases, then posts the alert, in that order. Kove clears only what
    // it set (PomodoroDnd).
    function reconcile(alert) {
        const now = Date.now();
        const until = hub.focusEnd();
        const result = until > 0 ? Dnd.engage(hub.dndState, hub.dnd.untilMs, until, now) : Dnd.release(hub.dndState, hub.dnd.untilMs, now, alert !== null);
        hub.dndState = result.state;
        const effects = result.effects;
        if (alert !== null && !effects.some(e => e.op === "alert"))
            effects.push({ "op": "alert" });
        for (const effect of effects) {
            if (effect.op === "set")
                hub.dnd.setUntil(effect.until);
            else if (effect.op === "clear")
                hub.dnd.clear();
            else if (alert !== null)
                hub.postAlert(alert.pid, alert.description);
        }
    }

    function postAlert(pid, description) {
        hub.notifier.post(hub.strings.pomodoroAlertTitle(description), "", "chronometer", id => {
            // The id arrives late: a timer that moved on since must not own this notification's Start button.
            if (hub.timers[pid]?.state.status !== "ended")
                return;
            hub.alertIds[pid] = id;
            hub.revision++;
        });
    }

    // A deadline passed. The phase end pauses and waits; DND is lifted first, then the alert goes out.
    function finishDue() {
        const now = Date.now();
        for (const pid of Object.keys(hub.timers)) {
            const entry = hub.timers[pid];
            const r = Engine.tick(entry.state, entry.cfg, now);
            if (r.finished === null)
                continue;
            entry.state = r.state;
            hub.nowMs = now;
            hub.revision++;
            hub.reconcile({ "pid": pid, "description": Engine.alert(r.finished, r.state, entry.cfg) });
        }
        hub.schedule();
    }

    function schedule() {
        const ends = Object.keys(hub.timers).map(pid => hub.timers[pid].state).filter(s => s.status === "running").map(s => s.endsAt);
        if (ends.length === 0)
            deadline.stop();
        else {
            deadline.interval = Math.max(20, Math.min.apply(null, ends) - Date.now() + 30);
            deadline.restart();
        }
    }

    // Drops the timers of placements that no longer exist, lifting any DND they held.
    function prune() {
        const keep = {};
        for (const pid of hub.livePids)
            keep[pid] = true;
        let dropped = false;
        for (const pid of Object.keys(hub.timers)) {
            if (!keep[pid]) {
                delete hub.timers[pid];
                delete hub.alertIds[pid];
                dropped = true;
            }
        }
        if (dropped) {
            hub.revision++;
            hub.reconcile(null);
        }
    }

    onLivePidsChanged: hub.prune()
    onRevisionChanged: hub.schedule()

    Timer {
        id: deadline

        onTriggered: hub.finishDue()
    }

    // The capsule's minutes and its thin bar step here; nothing renders per second.
    Timer {
        interval: T.pomodoroCoarseTick
        repeat: true
        running: hub.anyRunning
        onTriggered: hub.nowMs = Date.now()
    }

    Timer {
        interval: T.pomodoroFineTick
        repeat: true
        running: hub.ticking
        onTriggered: hub.nowMs = Date.now()
    }
}
