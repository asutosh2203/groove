import QtQuick
import QtQuick.Layouts
import QtTest
import "../contents/ui/services"
import "../contents/ui/shell"
import "../contents/ui/controlcenter/Tokens.js" as T

// Agent rows sit in a ColumnLayout (the Live list's header): an opened row must push the rows below it down and make the
// column taller, or it overlaps them and the list cannot scroll to the end of it (D-53).
TestCase {
    id: tc

    name: "AgentEntryAccordion"
    when: windowShown
    width: 400
    height: 400

    AgentService {
        id: agents
    }

    QtObject {
        id: fakeApp

        readonly property var agents: agents
        readonly property bool reduceMotion: true
        readonly property var deck: QtObject {
            property string openJob: ""
            function toggleJob(id) { openJob = openJob === id ? "" : id; }
        }
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
        function openAgent(id) {}
    }

    ListModel {
        id: ids

        ListElement { sid: "a" }
        ListElement { sid: "b" }
        ListElement { sid: "c" }
    }

    ColumnLayout {
        id: column

        parent: tc
        width: 300
        spacing: T.liveGap

        Repeater {
            id: rep

            model: ids

            delegate: AgentEntry {
                Layout.fillWidth: true
                app: fakeApp
            }
        }
    }

    function init() {
        fakeApp.deck.openJob = "";
        const base = Date.now() / 1000;
        agents.setSnapshot(JSON.stringify({ "v": 1, "sessions": ["a", "b", "c"].map(id => ({ "id": id, "state": "working", "project": "p", "pids": [], "startedAt": base, "updatedAt": base })) }));
    }

    function test_open_row_pushes_the_rest_down_and_grows_the_column() {
        const step = T.liveRowHeight + T.liveGap;
        tryCompare(rep.itemAt(1), "y", step);
        compare(column.implicitHeight, 3 * T.liveRowHeight + 2 * T.liveGap);
        fakeApp.deck.openJob = "agent:a";
        const extra = T.liveTileHeight - T.liveRowHeight;
        tryCompare(rep.itemAt(1), "y", step + extra);
        tryCompare(rep.itemAt(2), "y", 2 * step + extra);
        tryCompare(column, "implicitHeight", 3 * T.liveRowHeight + 2 * T.liveGap + extra);
        fakeApp.deck.openJob = "";
        tryCompare(rep.itemAt(1), "y", step);
    }
}
