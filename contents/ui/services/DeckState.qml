pragma ComponentBehavior: Bound

import QtQuick
import "../logic/DeckPlan.js" as DeckPlan
import "../logic/LiveLayout.js" as LiveLayout

// The deck's per-island state (D-51): the page cycle, the viewed page, the page opened last (this session only) and the
// Live pair. The decisions are pure (logic/DeckPlan.js, logic/LivePairs.js); this object feeds them the live inputs.
Item {
    id: state

    // Whether Live has anything to show: the cheap count that decides the cycle. The detailed jobs are only built while
    // the deck is visible (principle 9), so a running job's progress costs nothing while it is closed.
    required property int liveCount
    required property bool deckVisible
    required property bool liveMedia
    required property var liveJobs
    required property bool dummyPages
    required property bool controlEditing
    required property var geom

    property string current: "control"
    property string lastUsed: ""
    property var previousCycle: []

    readonly property var cycle: DeckPlan.buildCycle(liveCount > 0, dummyPages)
    readonly property var windowSize: DeckPlan.windowSize(cycle, geom)
    readonly property var liveLayout: LiveLayout.layout({ "hasMedia": deckVisible && liveMedia, "jobs": deckVisible ? liveJobs : [] })
    readonly property int liveShownCount: deckVisible ? liveLayout.count : liveCount
    readonly property var indicator: DeckPlan.indicator(cycle, current)

    function pageType(id) {
        for (const page of cycle) {
            if (page.id === id)
                return page.type === "live" ? DeckPlan.liveType(liveShownCount) : page.type;
        }
        return "small";
    }

    function sizeOf(id) {
        const type = pageType(id);
        if (type === "control" && controlEditing)
            return { "w": geom.controlEditW, "h": geom.controlEditH };
        return DeckPlan.pageSize(type, geom);
    }

    function open(intent) {
        current = DeckPlan.entryPage(cycle, lastUsed, intent);
    }

    function goTo(id) {
        current = id;
    }

    onCurrentChanged: lastUsed = current
    // Live appearing adds the pill and stays put; Live emptying moves on to the next page (or the Control Center).
    onCycleChanged: {
        current = DeckPlan.reconcile(previousCycle.length > 0 ? previousCycle : cycle, cycle, current);
        previousCycle = cycle;
    }
    Component.onCompleted: previousCycle = cycle
}
