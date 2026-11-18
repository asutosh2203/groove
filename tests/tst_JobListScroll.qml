import QtQuick
import QtTest
import "../contents/ui/services"
import "../contents/ui/shell"
import "../contents/ui/controlcenter/Tokens.js" as T

// The Live list with many agent rows (they sit in the list's header): the "more below" fade follows the scroll position,
// and an opened row is scrolled into view clear of that fade, top first when it cannot fit (D-53).
TestCase {
    id: tc

    name: "JobListScroll"
    visible: true
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
        id: noJobs
    }

    ListModel {
        id: ids

        ListElement { sid: "a" }
        ListElement { sid: "b" }
        ListElement { sid: "c" }
        ListElement { sid: "d" }
        ListElement { sid: "e" }
        ListElement { sid: "f" }
        ListElement { sid: "g" }
        ListElement { sid: "h" }
    }

    JobList {
        id: list

        parent: tc
        width: 300
        height: 180
        app: fakeApp
        model: noJobs
        agents: ids
        header: ({ "count": 0, "kind": "", "percent": 0, "remaining": 0, "rowGlyphs": false })
    }

    readonly property var rows: findChild(list, "rows")
    readonly property var fade: findChild(list, "moreFade")

    function init() {
        list.height = 180;
        fakeApp.deck.openJob = "";
        const base = Date.now() / 1000;
        agents.setSnapshot(JSON.stringify({ "v": 1, "sessions": ["a", "b", "c", "d", "e", "f", "g", "h"].map(id => ({ "id": id, "state": "working", "project": "p", "pids": [], "startedAt": base, "updatedAt": base })) }));
        tryCompare(rows.headerItem, "implicitHeight", 8 * T.liveRowHeight + 7 * T.liveGap);
        rows.pinnedTop = true;
        rows.contentY = rows.originY;
    }

    function entry(sid) {
        for (const c of rows.headerItem.children) {
            if (c["jid"] === "agent:" + sid)
                return c;
        }
        return null;
    }

    // The item's top and bottom edges in the list's own coordinates.
    function edges(it) {
        const y = it.mapToItem(list, 0, 0).y;
        return { "top": y, "bottom": y + it.height };
    }

    function scrollTo(y) {
        rows.pinnedTop = false;
        rows.contentY = y;
    }

    function test_fade_follows_the_scroll_position() {
        const maxY = rows.originY + rows.contentHeight - rows.height;
        verify(maxY > rows.originY, "the rows overflow");
        compare(fade.opacity, 1);
        let last = 1;
        let partial = false;
        for (let y = rows.originY; y <= maxY; y += 6) {
            scrollTo(y);
            verify(fade.opacity <= last + 1e-9, "never grows while scrolling down");
            last = fade.opacity;
            partial = partial || last > 0.05 && last < 0.95;
        }
        verify(partial, "it passes through partial opacity on the way");
        scrollTo(maxY);
        compare(fade.opacity, 0);
        compare(fade.visible, false);
        wait(1300); // it does not come back on its own
        compare(fade.visible, false);
        scrollTo(maxY - T.liveFadeMore / 2);
        fuzzyCompare(fade.opacity, 0.5, 0.01);
        scrollTo(rows.originY);
        compare(fade.opacity, 1);
    }

    function test_wheel_scrolls_and_fades() {
        mouseWheel(rows, 100, 90, 0, -240);
        tryVerify(() => rows.contentY > rows.originY + 20, 2000); // the wheel eases in, it does not jump
        tryVerify(() => !rows.moving, 3000);
        verify(fade.opacity < 1);
        compare(rows.pinnedTop, false);
    }

    // Clicks the row (a real press and release) and waits for the list to settle on it.
    function openByClick(sid) {
        const it = entry(sid);
        mouseClick(it, it.width / 2, 8);
        compare(fakeApp.deck.openJob, "agent:" + sid);
        tryVerify(() => Math.abs(entry(sid).height - T.liveTileHeight) < 0.5, 2000);
        wait(T.motionPage + 250);
    }

    function clearOfFade(sid) {
        const e = edges(entry(sid));
        verify(e.top >= -0.5, sid + " top is in view: " + e.top);
        verify(e.bottom <= rows.height - T.liveFadeMore + 0.5 || fade.visible === false, sid + " last line is clear of the fade: " + e.bottom + " / " + fade.opacity);
    }

    function test_opening_a_row_near_the_bottom_edge_scrolls_it_clear_of_the_fade() {
        const row = entry("c");
        // Put c right under the fade's top edge, so opening it would reach into the fade.
        scrollTo(row.mapToItem(rows.contentItem, 0, 0).y + T.liveRowHeight - rows.height + 6);
        const before = rows.contentY;
        openByClick("c");
        clearOfFade("c");
        verify(rows.contentY > before, "scrolled to follow the opened row");
    }

    function test_opening_the_last_row_scrolls_to_the_end_and_is_fully_visible() {
        const maxY = rows.originY + rows.contentHeight - rows.height;
        scrollTo(maxY);
        openByClick("h");
        const e = edges(entry("h"));
        verify(e.bottom <= rows.height + 0.5, "h's bottom is in view: " + e.bottom);
        verify(e.top >= -0.5);
        compare(fade.visible, false);
        // and it can be scrolled to the very end of
        scrollTo(rows.originY + rows.contentHeight - rows.height);
        compare(fade.visible, false);
    }

    function test_opening_a_row_already_clear_does_not_move_the_list() {
        openByClick("a");
        fuzzyCompare(rows.contentY, rows.originY, 0.5);
        clearOfFade("a");
    }

    function test_a_row_taller_than_the_view_keeps_its_top_in_view() {
        list.height = 80; // shorter than a tile
        wait(50);
        scrollTo(rows.originY + (T.liveRowHeight + T.liveGap) * 4);
        openByClick("e");
        const e = edges(entry("e"));
        verify(e.top >= -0.5 && e.top < 4, "the top is at the top: " + e.top);
    }

    function test_collapsing_leaves_the_list_within_its_bounds() {
        scrollTo(rows.originY + rows.contentHeight - rows.height);
        openByClick("h");
        fakeApp.deck.openJob = "";
        wait(T.motionPage + 250);
        verify(rows.contentY >= rows.originY - 0.5);
        verify(rows.contentY <= rows.originY + Math.max(0, rows.contentHeight - rows.height) + 0.5);
    }
}
