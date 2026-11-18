import QtQuick
import QtTest
import "../contents/ui/services"
import "../contents/ui/shell"

// A Changed snapshot must update tiles in place: the delegate for a session id is created once and never rebuilt (D-58).
TestCase {
    id: tc

    name: "AgentTileInPlace"
    when: windowShown
    width: 400
    height: 200

    property int created: 0

    AgentService {
        id: agents
    }

    QtObject {
        id: fakeApp

        readonly property var agents: agents
        readonly property var strings: QtObject {
            readonly property string agentNeedsOk: "ok"
            readonly property string jobCollapse: "c"
            function agentSubtitleTail(d) { return d; }
            function agentMinutes(m) { return m + "m"; }
            function agentDone(m) { return "d"; }
            function agentProgress(a, b) { return a + "/" + b; }
            function agentWants(a, t) { return t; }
            function agentAction(a, t) { return t; }
            function agentCountdownLine(t) { return t; }
            function agentSubagents(x) { return x.count + ""; }
            function agentClockLeft(c) { return c; }
        }
        readonly property bool reduceMotion: true
        function openAgent(id) {}
    }

    ListModel {
        id: ids

        ListElement { sid: "a" }
        ListElement { sid: "b" }
    }

    Repeater {
        id: rep

        parent: tc
        model: ids

        delegate: AgentTile {
            app: fakeApp
            width: 300
            height: 100
            Component.onCompleted: tc.created++
        }
    }

    function snap(n) {
        const base = Date.now() / 1000;
        const s = id => ({ "id": id, "state": "working", "project": "groove", "pids": [], "startedAt": base, "updatedAt": base + n,
                           "action": "run", "target": "make " + n, "toolStartedAt": base - n, "done": n % 5, "total": 5,
                           "countdown": n % 2 ? { "total": 300, "startedAt": base } : null,
                           "subagents": n % 3 ? [{ "id": "x" + n, "type": "general-purpose" }] : [] });
        return JSON.stringify({ "v": 1, "sessions": [s("a"), s("b")] });
    }

    function test_snapshots_never_recreate_tiles() {
        agents.setSnapshot(snap(0));
        compare(rep.count, 2);
        const before = tc.created;
        verify(before >= 2);
        for (let i = 1; i <= 50; ++i)
            agents.setSnapshot(snap(i));
        compare(tc.created, before);
        compare(rep.count, 2);
        compare(rep.itemAt(0).sid, "a");
    }
}
