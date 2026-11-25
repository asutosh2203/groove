import QtQuick
import QtTest
import "../contents/ui/services" as Services

// D-64: the timer service runs the pure engine, keeps Plasma's DND in step and posts the phase-end alert after lifting it.
Item {
    id: testRoot

    width: 100
    height: 100

    property var log: []
    property var posted: []

    QtObject {
        id: fakeDnd

        property var untilMs: null

        function setUntil(ms) {
            untilMs = ms;
            testRoot.log.push("set");
        }

        function clear() {
            untilMs = null;
            testRoot.log.push("clear");
        }
    }

    QtObject {
        id: fakeNotifier

        function post(summary, body, icon, onId) {
            testRoot.log.push("post");
            testRoot.posted.push(summary);
            onId(77);
        }
    }

    QtObject {
        id: fakeStrings

        function pomodoroAlertTitle(a) {
            return a.kind;
        }
    }

    Services.TimerService {
        id: hub

        dnd: fakeDnd
        notifier: fakeNotifier
        strings: fakeStrings
    }

    readonly property var settings: ({ "focus": 25, "break": 5, "rounds": 2, "longBreak": 0, "dnd": true })

    TestCase {
        name: "TimerService"
        when: windowShown

        function init() {
            for (const pid of Object.keys(hub.timers))
                delete hub.timers[pid];
            hub.revision++;
            hub.dndState = { "ours": false };
            fakeDnd.untilMs = null;
            testRoot.log = [];
            testRoot.posted = [];
        }

        function test_nothing_ticks_until_a_timer_runs_and_a_view_holds_seconds() {
            hub.ensure("a", testRoot.settings);
            compare(hub.anyRunning, false);
            hub.holdSeconds();
            compare(hub.ticking, false);
            hub.toggle("a");
            compare(hub.anyRunning, true);
            compare(hub.ticking, true);
            hub.releaseSeconds();
            compare(hub.ticking, false);
            hub.toggle("a");
            compare(hub.anyRunning, false);
        }

        function test_focus_sets_dnd_to_its_end_and_pause_clears_only_that() {
            hub.ensure("a", testRoot.settings);
            hub.toggle("a");
            compare(testRoot.log.join(), "set");
            verify(fakeDnd.untilMs > Date.now() + 24 * 60000);
            compare(hub.capsule.tier, "focus");
            hub.toggle("a");
            compare(testRoot.log.join(), "set,clear");
            compare(fakeDnd.untilMs, null);
            compare(hub.active, false);
        }

        function test_a_dnd_the_user_already_had_is_left_alone() {
            fakeDnd.untilMs = Date.now() + 5 * 3600000;
            hub.ensure("a", testRoot.settings);
            hub.toggle("a");
            hub.toggle("a");
            compare(testRoot.log.join(), "");
            verify(fakeDnd.untilMs > Date.now() + 4 * 3600000);
        }

        function test_the_phase_end_lifts_dnd_before_the_alert_and_waits() {
            hub.ensure("a", testRoot.settings);
            hub.toggle("a");
            hub.timers["a"].state.endsAt = Date.now() - 1;
            hub.finishDue();
            compare(testRoot.log.join(), "set,clear,post");
            compare(testRoot.posted.join(), "focusDone");
            compare(hub.info("a").status, "ended");
            compare(hub.info("a").done, 1);
            compare(hub.isAlert(77), true);
            compare(hub.capsule.dot, true);
            compare(hub.capsule.tier, "break");
            hub.startFromAlert(77);
            compare(hub.info("a").status, "running");
            compare(hub.info("a").kind, "break");
            compare(hub.isAlert(77), false);
        }

        function test_the_timer_with_dnd_off_never_touches_it() {
            hub.ensure("a", Object.assign({}, testRoot.settings, { "dnd": false }));
            hub.toggle("a");
            compare(testRoot.log.join(), "");
        }

        function test_a_ready_timer_follows_settings_but_a_running_one_keeps_its_own_until_reset() {
            hub.ensure("a", testRoot.settings);
            hub.ensure("a", Object.assign({}, testRoot.settings, { "focus": 30 }));
            compare(hub.info("a").remainingMs, 30 * 60000);
            hub.toggle("a");
            hub.ensure("a", Object.assign({}, testRoot.settings, { "focus": 45 }));
            verify(hub.info("a").remainingMs <= 30 * 60000);
            hub.reset("a");
            compare(hub.info("a").remainingMs, 45 * 60000);
        }

        function test_a_removed_placement_drops_its_timer_and_its_dnd() {
            hub.livePids = ["a"];
            hub.ensure("a", testRoot.settings);
            hub.toggle("a");
            hub.livePids = [];
            compare(hub.has("a"), false);
            compare(fakeDnd.untilMs, null);
        }

        function test_live_order_puts_a_waiting_timer_first() {
            hub.ensure("a", testRoot.settings);
            hub.ensure("b", testRoot.settings);
            hub.toggle("a");
            hub.toggle("b");
            hub.skip("b");
            compare(hub.liveTimers.map(t => t.pid).join(), "b,a");
            compare(hub.lead.pid, "b");
        }
    }
}
