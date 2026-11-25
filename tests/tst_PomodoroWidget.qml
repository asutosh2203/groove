import QtQuick
import QtTest
import "../contents/ui/services" as Services
import "../contents/ui/widgets/pomodoro" as Pomodoro

// D-64: the Pomodoro views draw from the service in place, their buttons act on it, and a view holds the 1 Hz clock only
// while it exists.
Item {
    id: testRoot

    width: 420
    height: 120

    QtObject {
        id: fakeDnd

        property var untilMs: null

        function setUntil(ms) {}
        function clear() {}
    }

    QtObject {
        id: fakeNotifier

        function post(summary, body, icon, onId) {}
    }

    QtObject {
        id: fakeStrings

        function pomodoroPhase(kind, plain) { return plain ? "Timer" : kind; }
        readonly property string pomodoroReady: "Pomodoro"
        readonly property string pomodoroTimerReady: "Timer"
        readonly property string pomodoroPlay: "Start"
        readonly property string pomodoroPause: "Pause"
        readonly property string pomodoroSkip: "Skip"
        readonly property string pomodoroReset: "Reset"
        readonly property string pomodoroDoneCycle: "Done"
        function pomodoroRound(r, n) { return "Round " + r + " of " + n; }
        function pomodoroPlainOf(m) { return "of " + m + " min"; }
        function pomodoroReadyDetail(r, f, b) { return r + " rounds · " + f + " / " + b; }
        function pomodoroNextIs(k) { return k + "'s next"; }
        function pomodoroNext(p) { return p ? "Next: " + p.kind : "Cycle ends"; }
        function pomodoroNextLong(p, a) { return p ? p.kind + " next" : ""; }
        function pomodoroDone(n) { return n + " done"; }
        function pomodoroNextRound(k, r, n) { return k + " " + r + " of " + n + " next"; }
        function pomodoroCycle(m) { return "Cycle · " + m; }
        function pomodoroLongAt(t) { return "Long at " + t; }
        function pomodoroAlertTitle(a) { return a.kind; }
    }

    Services.TimerService {
        id: timerHub

        dnd: fakeDnd
        notifier: fakeNotifier
        strings: fakeStrings
    }

    Component {
        id: view1

        Pomodoro.View1x1 {
            width: 154
            height: 96
            pid: "t"
            services: ({ "timer": timerHub })
            strings: fakeStrings
            settings: ({ "focus": 25, "break": 5, "rounds": 4, "longBreak": 15, "dnd": false })
        }
    }

    Component {
        id: bare

        Pomodoro.View1x1 {
            width: 154
            height: 96
            pid: "t"
            strings: fakeStrings
            settings: ({ "focus": 25, "break": 5, "rounds": 4, "longBreak": 15, "dnd": false })
        }
    }

    Component {
        id: view2

        Pomodoro.View2x1 {
            width: 320
            height: 96
            pid: "t"
            services: ({ "timer": timerHub })
            strings: fakeStrings
            settings: ({ "focus": 25, "break": 5, "rounds": 4, "longBreak": 15, "dnd": false })
        }
    }

    Component {
        id: view4

        Pomodoro.View4x1 {
            width: 640
            height: 96
            pid: "t"
            services: ({ "timer": timerHub })
            strings: fakeStrings
            settings: ({ "focus": 25, "break": 5, "rounds": 4, "longBreak": 15, "dnd": false })
        }
    }

    TestCase {
        name: "PomodoroWidget"
        when: windowShown

        function named(item, name) {
            if (item.objectName === name)
                return item;
            for (let i = 0; i < item.children.length; ++i) {
                const found = named(item.children[i], name);
                if (found)
                    return found;
            }
            return null;
        }

        function texts(item, out) {
            if (item.text !== undefined && item.visible)
                out.push(String(item.text));
            for (let i = 0; i < item.children.length; ++i)
                texts(item.children[i], out);
            return out;
        }

        function init() {
            for (const pid of Object.keys(timerHub.timers))
                delete timerHub.timers[pid];
            timerHub.revision++;
        }

        function test_ready_face_then_play_updates_in_place() {
            const v = createTemporaryObject(view1, testRoot);
            verify(v);
            compare(v.hero, "25:00");
            compare(v.label, "Pomodoro");
            compare(v.detail, "4 rounds · 25 / 5");
            const play = named(v, "play");
            verify(play.width >= 22 && play.height >= 22);
            mouseClick(play);
            compare(timerHub.info("t").status, "running");
            compare(v.label, "focus");
            compare(v.detail, "Round 1 of 4");
            mouseClick(play);
            compare(timerHub.info("t").status, "paused");
            const reset = named(v, "resetPaused");
            verify(reset.visible && reset.x < play.x && reset.width >= 22);
            mouseClick(reset);
            compare(timerHub.info("t").status, "ready");
            verify(!reset.visible);
        }

        function test_a_view_holds_the_second_clock_only_while_it_exists() {
            compare(timerHub.secondHolds, 0);
            const v = createTemporaryObject(view1, testRoot);
            compare(timerHub.secondHolds, 1);
            v.destroy();
            wait(0);
            tryCompare(timerHub, "secondHolds", 0);
        }

        function test_services_injected_after_loading_still_hold_the_clock() {
            const v = createTemporaryObject(bare, testRoot);
            compare(timerHub.secondHolds, 0);
            v.services = { "timer": timerHub };
            compare(timerHub.secondHolds, 1);
            v.destroy();
            tryCompare(timerHub, "secondHolds", 0);
        }

        function test_a_button_with_nothing_to_do_is_dimmed_not_hidden() {
            const v = createTemporaryObject(view2, testRoot);
            const skip = named(v, "skip");
            verify(skip.visible);
            compare(skip.enabled, false);
            verify(skip.opacity < 1);
            timerHub.play("t");
            compare(skip.enabled, true);
            compare(skip.opacity, 1);
        }

        function test_the_2x1_buttons_skip_and_reset() {
            const v = createTemporaryObject(view2, testRoot);
            timerHub.play("t");
            mouseClick(named(v, "skip"));
            compare(timerHub.info("t").status, "ended");
            compare(v.detail, "break's next · ▶");
            compare(v.hero, "0:00");
            mouseClick(named(v, "reset"));
            compare(timerHub.info("t").status, "ready");
        }

        function test_the_4x1_shows_the_cycle_and_the_done_count() {
            const v = createTemporaryObject(view4, testRoot);
            timerHub.play("t");
            timerHub.timers["t"].state.endsAt = Date.now() - 1;
            timerHub.finishDue();
            const all = texts(v, []);
            verify(all.indexOf("Cycle · 130") >= 0, all.join("|"));
            verify(all.indexOf("1 done") >= 0, all.join("|"));
        }

        function test_a_plain_timer_reads_timer_not_focus() {
            const v = createTemporaryObject(view1, testRoot);
            v.settings = { "focus": 10, "break": 0, "rounds": 1, "longBreak": 0, "dnd": false };
            compare(v.label, "Timer");
            timerHub.play("t");
            compare(v.label, "Timer");
            compare(v.detail, "of 10 min");
        }
    }
}
