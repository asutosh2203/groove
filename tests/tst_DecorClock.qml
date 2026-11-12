import QtQuick
import QtTest
import "../contents/ui" as UI

Item {
    id: testRoot
    width: 100
    height: 100

    UI.DecorClock { id: clock }
    UI.DecorClockLease { id: leaseA; clock: clock; fps: 8 }
    UI.DecorClockLease { id: leaseB; clock: clock; fps: 12 }

    property int ticks: 0
    Connections { target: clock; function onTimeChanged() { testRoot.ticks++ } }

    TestCase {
        name: "DecorClock"
        when: windowShown

        function init() {
            leaseA.active = false;
            leaseB.active = false;
            wait(50);
            testRoot.ticks = 0;
        }

        function test_idle_clock_does_not_tick() {
            compare(clock.running, false);
            wait(400);
            compare(testRoot.ticks, 0);
        }

        function test_a_lease_starts_it_at_its_rate_and_releasing_stops_it() {
            leaseA.active = true;
            compare(clock.running, true);
            compare(clock.fps, 8);
            wait(1000);
            // 8 fps for one second, within generous scheduling slack
            verify(testRoot.ticks >= 5 && testRoot.ticks <= 11, "ticks in 1 s at 8 fps: " + testRoot.ticks);
            leaseA.active = false;
            compare(clock.running, false);
            const after = testRoot.ticks;
            wait(400);
            compare(testRoot.ticks, after);
        }

        function test_the_highest_requested_rate_wins_and_drops_back() {
            leaseA.active = true;
            leaseB.active = true;
            compare(clock.fps, 12);
            leaseB.active = false;
            compare(clock.fps, 8);
            compare(clock.running, true);
            leaseA.active = false;
            compare(clock.running, false);
        }

        function test_time_advances_with_the_wall_clock() {
            leaseA.active = true;
            const t0 = clock.time;
            wait(500);
            verify(clock.time - t0 >= 300, "time moved by " + (clock.time - t0));
        }
    }
}
