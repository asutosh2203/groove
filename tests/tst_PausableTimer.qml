import QtQuick
import QtTest
import "../contents/ui" as UI

Item {
    id: testRoot
    width: 100
    height: 100

    UI.PausableTimer {
        id: timer
        duration: 400
        onTriggered: testRoot.fired++
    }

    property int fired: 0

    TestCase {
        name: "PausableTimer"
        when: windowShown

        function init() {
            timer.stop();
            timer.hold = false;
            testRoot.fired = 0;
        }

        function test_runs_and_fires_once() {
            timer.restart();
            compare(timer.running, true);
            tryCompare(testRoot, "fired", 1, 1500);
            compare(timer.running, false);
        }

        function test_hold_stops_the_countdown() {
            timer.restart();
            wait(150);
            timer.hold = true;
            compare(timer.running, true);   // still counts as an active lifetime while held
            wait(700);                      // well past the 400 ms duration
            compare(testRoot.fired, 0);
            compare(timer.held, true);
        }

        function test_release_finishes_with_the_remaining_time() {
            timer.restart();
            wait(200);                      // about 200 ms spent
            timer.hold = true;
            wait(500);
            timer.hold = false;
            const releasedAt = Date.now();
            tryCompare(testRoot, "fired", 1, 1500);
            const after = Date.now() - releasedAt;
            // Roughly the 200 ms that were left: far less than a full 400 ms restart.
            verify(after < 330, "finished after " + after + " ms, expected about the remaining 200 ms");
        }

        function test_restart_while_held_stays_held_with_full_duration() {
            timer.hold = true;
            timer.restart();
            wait(600);
            compare(testRoot.fired, 0);
            compare(timer.held, true);
            timer.hold = false;
            tryCompare(testRoot, "fired", 1, 1500);
        }

        function test_stop_clears_a_held_timer() {
            timer.restart();
            timer.hold = true;
            timer.stop();
            compare(timer.running, false);
            timer.hold = false;
            wait(600);
            compare(testRoot.fired, 0);
        }
    }
}
