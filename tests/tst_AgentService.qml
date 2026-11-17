import QtQuick
import QtTest
import "../contents/ui/services"

// The aggregator is not running under test, so this covers the idle state and the snapshot path through setSnapshot.
// The parsing, ordering and window matching are pure and tested in tests/agents.test.cjs.
TestCase {
    id: tc

    name: "AgentService"
    when: windowShown

    property int started: 0

    AgentService {
        id: agents

        onAgentStarted: tc.started++
    }

    function snap(sessions) {
        return JSON.stringify({ "v": 1, "sessions": sessions });
    }

    function session(id, state, startedAt) {
        return { "id": id, "state": state, "project": "groove", "pids": [999999], "startedAt": startedAt, "updatedAt": startedAt };
    }

    function init() {
        agents.setSnapshot("");
        tc.started = 0;
    }

    function test_idle_without_an_aggregator() {
        verify(!agents.available);
        verify(!agents.hasAgents);
        verify(!agents.raise("nothing"));
    }

    function test_snapshot_orders_and_announces_new_sessions() {
        agents.setSnapshot(snap([session("w", "working", 5), session("q", "waiting", 1), session("d", "done", 9)]));
        compare(agents.sessions.map(s => s.id).join(), "q,w,d");
        compare(tc.started, 1);
        agents.setSnapshot(snap([session("w", "waiting", 5)]));
        compare(tc.started, 1);
        agents.setSnapshot("{broken");
        verify(!agents.hasAgents);
    }

    function test_no_window_means_not_raisable() {
        agents.setSnapshot(snap([session("w", "working", 5)]));
        compare(agents.raisable["w"], false);
        verify(!agents.raise("w"));
    }
}
