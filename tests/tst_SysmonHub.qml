import QtQuick
import QtTest
import "../contents/ui/services" as Services

// D-65: the sensor hub creates Sensor objects and runs its clock only for placed widgets, follows the views' hold for its
// cadence, and stops while the screen is locked. No test here needs ksystemstats to answer.
Item {
    id: testRoot

    width: 100
    height: 100

    property var subs: []

    QtObject {
        id: fakeNotifier

        function post(summary, body, icon, onId) {
        }
    }

    QtObject {
        id: fakeStrings

        function sysmonAlert(kind, value, seconds) {
            return kind;
        }
    }

    Services.SysmonHub {
        id: hub

        subscriptions: testRoot.subs
        inspecting: false
        notifier: fakeNotifier
        strings: fakeStrings
    }

    TestCase {
        name: "SysmonHub"
        when: windowShown

        function init() {
            testRoot.subs = [];
            while (hub.viewers.count > 0)
                hub.releaseView();
            hub.setLocked(false);
        }

        function test_nothing_exists_with_no_widget() {
            tryVerify(() => hub.sensorTotal() === 0);
            compare(hub.sampling, false);
            compare(hub.face("cpu").state, "loading");
        }

        function test_sensors_follow_the_placements_and_share() {
            testRoot.subs = [{ "pid": "a", "kinds": ["cpu", "gpu"], "alerts": false }, { "pid": "b", "kinds": ["gpu"], "alerts": true }];
            tryVerify(() => hub.sensorTotal() === 5);
            compare(hub.sampling, true);
            testRoot.subs = [];
            tryVerify(() => hub.sensorTotal() === 0);
            compare(hub.sampling, false);
        }

        function test_cadence_follows_the_views() {
            testRoot.subs = [{ "pid": "a", "kinds": ["cpu"], "alerts": false }];
            compare(hub.tick, 5000);
            hub.holdView();
            compare(hub.tick, 1000);
            hub.holdView();
            hub.releaseView();
            compare(hub.tick, 1000);
            hub.releaseView();
            compare(hub.tick, 5000);
        }

        function test_locked_stops_the_clock() {
            testRoot.subs = [{ "pid": "a", "kinds": ["cpu"], "alerts": false }];
            compare(hub.sampling, true);
            hub.setLocked(true);
            compare(hub.sampling, false);
            hub.setLocked(false);
            compare(hub.sampling, true);
        }

        function test_removing_a_placement_drops_its_history() {
            testRoot.subs = [{ "pid": "a", "kinds": ["cpu"], "alerts": false }];
            hub.rings = { "cpu/all/usage": [{ "t": 1, "v": 1, "tick": 1000 }], "gpu/gpu0/usage": [] };
            testRoot.subs = [{ "pid": "a", "kinds": ["ram"], "alerts": false }];
            compare(Object.keys(hub.rings).length, 0);
        }

        function test_a_dead_sensor_keeps_no_hot_state_from_its_last_value() {
            testRoot.subs = [{ "pid": "a", "kinds": ["gpuTemp"], "alerts": true }];
            hub.latest = { "gpu/gpu0/temperature": 95 };
            hub.healths = { "gpu/gpu0/temperature": "ready" };
            hub.evaluate(Date.now());
            compare(hub.alertStates.gpuTemp.hot, true);
            hub.healths = { "gpu/gpu0/temperature": "removed" };
            hub.evaluate(Date.now() + 1000);
            compare(hub.alertStates.gpuTemp, undefined);
            hub.healths = { "gpu/gpu0/temperature": "unresponsive" };
            hub.evaluate(Date.now() + 2000);
            compare(hub.alertStates.gpuTemp, undefined);
        }
    }
}
