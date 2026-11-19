import QtQuick
import QtTest
import "../contents/ui/services"
import "../contents/ui/widgets/claude-code" as Claude
import "../contents/ui/controlcenter/Tokens.js" as T

// D-60: the Claude Code views read the agent service. The face follows the snapshot, and rows update in place.
Item {
    id: host

    width: 400
    height: 300

    TestCase {
        id: tc

        name: "ClaudeWidget"
        when: windowShown
        parent: host

        AgentService {
            id: svc
        }

        QtObject {
            id: fakeStrings

            readonly property string claudeLabel: "Claude Code"
            readonly property string claudeCaughtUp: "All caught up"
            readonly property string claudeNoRecent: "No recent sessions"
            function claudeLimit(weekly, when) { return (weekly ? "Weekly" : "5h") + " limit · " + when; }
            function claudeWeek(p, d) { return "This week " + p; }
            function claudeAttention(n) { return n + " needs your OK"; }
            function claudeRunning(n) { return n + " running"; }
            function claudeCost(u) { return "$" + u.toFixed(2); }
            function claudeCostSessions(n) { return n + " sessions"; }
            function claudeLast(p, m) { return "Last: " + p; }
            function claudeRowTail(t) { return t ? " · " + t : ""; }
            function claudeLines(a, r) { return "+" + a + " -" + r; }
            function claudeNeedsOkLine(t) { return "Needs your OK · " + t; }
            function agentWants(a, t) { return "Wants to run: " + t; }
            function agentAction(a, t) { return "doing " + t; }
        }

        Component {
            id: view1

            Claude.View1x1 {
                width: 154
                height: 104
                services: ({ "agents": svc })
                strings: fakeStrings
                reduceMotion: true
            }
        }

        Component {
            id: view2

            Claude.View2x1 {
                width: 328
                height: 104
                services: ({ "agents": svc })
                strings: fakeStrings
                reduceMotion: true
            }
        }

        function snap(sessions, usage) {
            const s = { "v": 1, "sessions": sessions };
            if (usage)
                s.usage = usage;
            svc.setSnapshot(JSON.stringify(s));
        }

        function session(id, state, extra) {
            return Object.assign({ "id": id, "state": state, "project": "Kove", "startedAt": 100, "updatedAt": 100, "pids": [], "action": "edit", "target": "a.qml" }, extra || {});
        }

        function plan() {
            return { "fiveHour": { "pct": 34, "resetsAt": Math.floor(Date.now() / 1000) + 3600 } };
        }

        // Every Text under an item.
        function texts(item) {
            let out = [];
            if (item.text !== undefined && item.visible)
                out.push(String(item.text));
            for (let i = 0; i < item.children.length; ++i)
                out = out.concat(texts(item.children[i]));
            return out;
        }

        function rowItems(item) {
            let out = [];
            if (item.info !== undefined)
                out.push(item);
            for (let i = 0; i < item.children.length; ++i)
                out = out.concat(rowItems(item.children[i]));
            return out;
        }

        function sortedRows(item) {
            return rowItems(item).sort((a, b) => a.y - b.y);
        }

        function init() {
            svc.usage = ({});
            svc.sawLimits = false;
            svc.spend = ({});
            svc.recent = [];
            snap([]);
        }

        function test_usage_while_running() {
            snap([session("a", "working")], plan());
            const v = createTemporaryObject(view1, host);
            tryVerify(() => texts(v).indexOf("34%") >= 0);
            verify(texts(v).some(t => t.indexOf("5h limit") === 0));
        }

        function test_attention_replaces_the_detail() {
            snap([session("a", "waiting", { "waitingAction": "run", "waitingCommand": "git push" })], plan());
            const v = createTemporaryObject(view1, host);
            tryVerify(() => texts(v).indexOf("1 needs your OK") >= 0);
        }

        function test_resting_and_the_ring_survives_a_snapshot_without_limits() {
            snap([session("a", "working")], plan());
            snap([session("a", "done")]);
            const v = createTemporaryObject(view1, host);
            tryVerify(() => texts(v).indexOf("All caught up") >= 0);
            verify(texts(v).indexOf("34%") >= 0);
            compare(v.clickAction, null);
        }

        function test_neutral_resting_shows_no_zero() {
            const v = createTemporaryObject(view1, host);
            tryVerify(() => texts(v).indexOf("All caught up") >= 0);
            verify(texts(v).indexOf("0") < 0 && texts(v).indexOf("Idle") < 0);
        }

        function test_spend_mode() {
            snap([session("a", "working", { "costUsd": 1.844 })]);
            const v = createTemporaryObject(view1, host);
            tryVerify(() => texts(v).indexOf("$1.84") >= 0);
        }

        function test_rows_update_in_place() {
            snap([session("a", "working", { "contextPct": 10 }), session("b", "working", { "startedAt": 50 })], plan());
            const v = createTemporaryObject(view2, host);
            tryVerify(() => rowItems(v).length === 2);
            const first = rowItems(v)[0];
            for (let i = 0; i < 30; ++i)
                snap([session("a", "working", { "contextPct": i, "linesAdded": i }), session("b", "working", { "startedAt": 50 })], plan());
            tryVerify(() => rowItems(v)[0].info.added === 29);
            verify(rowItems(v)[0] === first);
        }

        function test_waiting_row_shows_its_command_and_none_means_the_empty_note() {
            const v = createTemporaryObject(view2, host);
            tryVerify(() => texts(v).indexOf("No recent sessions") >= 0);
            snap([session("a", "waiting", { "waitingAction": "run", "waitingCommand": "git push origin" }), session("b", "working", { "startedAt": 50 }), session("c", "working", { "startedAt": 40 })]);
            tryVerify(() => texts(v).indexOf("Needs your OK · git push origin") >= 0);
            verify(texts(v).indexOf("No recent sessions") < 0);
            verify(rowItems(v).length < 3); // the box fits two; the waiting row is kept
            compare(rowItems(v)[0].info.id, "a");
        }

        function test_finished_sessions_become_recent_rows() {
            snap([session("a", "working")]);
            snap([session("a", "done", { "lastMessage": "Added it.", "updatedAt": 160 })]);
            snap([]);
            const v = createTemporaryObject(view2, host);
            tryVerify(() => rowItems(v).length === 1);
            compare(rowItems(v)[0].info.state, "done");
            verify(texts(v).some(t => t.indexOf("Added it.") >= 0));
        }

        function test_two_rows_at_most_filling_the_column() {
            snap([session("a", "working", { "startedAt": 100 }), session("b", "working", { "startedAt": 90 }), session("c", "working", { "startedAt": 80 })], plan());
            const v = createTemporaryObject(view2, host);
            tryVerify(() => rowItems(v).length === 2);
            const r = sortedRows(v);
            compare(r[0].info.id, "a");
            compare(r[1].info.id, "b");
            fuzzyCompare(r[0].y, T.hoverInset, 0.01);
            fuzzyCompare(r[0].y + r[0].height + T.hoverInset, r[1].y, 0.01);
            fuzzyCompare(r[1].y + r[1].height, v.height - T.hoverInset, 0.01);
            fuzzyCompare(r[0].height, r[1].height, 0.01);
        }

        function test_waiting_slot_is_taller_and_a_promotion_keeps_the_older_row() {
            snap([session("a", "working", { "startedAt": 100 }), session("b", "working", { "startedAt": 90 }), session("c", "working", { "startedAt": 80 })], plan());
            const v = createTemporaryObject(view2, host);
            tryVerify(() => rowItems(v).length === 2);
            const items = sortedRows(v);
            const itemA = items[0];
            const itemB = items[1];
            snap([session("a", "working", { "startedAt": 100 }), session("b", "waiting", { "startedAt": 90, "updatedAt": 100, "waitingAction": "run", "waitingCommand": "ls" }), session("c", "working", { "startedAt": 80 })], plan());
            tryVerify(() => itemB.waiting);
            tryVerify(() => itemB.height > itemA.height);
            fuzzyCompare(itemA.y + itemA.height + T.hoverInset, itemB.y, 0.01);
            // a hidden session starts waiting: the quiet row a is replaced, the older wait (b) goes on top
            snap([session("a", "working", { "startedAt": 100 }), session("b", "waiting", { "startedAt": 90, "updatedAt": 100, "waitingAction": "run", "waitingCommand": "ls" }), session("c", "waiting", { "startedAt": 80, "updatedAt": 200, "waitingAction": "run", "waitingCommand": "rm" })], plan());
            tryVerify(() => sortedRows(v).map(x => x.info.id).join() === "b,c");
            verify(sortedRows(v)[0] === itemB); // the same item slid up: nothing was recreated
            fuzzyCompare(sortedRows(v)[0].height, sortedRows(v)[1].height, 0.01);
            // approving b leaves it where it is, as a working row
            snap([session("a", "working", { "startedAt": 100 }), session("b", "working", { "startedAt": 90, "updatedAt": 300 }), session("c", "waiting", { "startedAt": 80, "updatedAt": 200, "waitingAction": "run", "waitingCommand": "rm" })], plan());
            tryVerify(() => itemB.waiting === false);
            compare(sortedRows(v).map(x => x.info.id).join(), "b,c");
        }
    }
}
