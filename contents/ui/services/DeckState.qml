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

    readonly property var presets: dummyPages ? DeckPlan.dummyPresets() : []
    readonly property var cycle: DeckPlan.buildCycle(liveCount > 0, presets)
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

    // The Live page's top inset plus the bottom inset that holds the indicator: what a page keeps clear around its content.
    readonly property real liveChrome: {
        const ins = DeckPlan.insets(false, geom.padding);
        return ins.t + ins.b;
    }
    // The media card keeps its Small-page height wherever it sits.
    readonly property real mediaHeight: geom.cellH - liveChrome

    // The rail shows when there are two or more pages, except while the Control Center is being edited.
    function railOn(id) {
        return cycle.length > 1 && !(id === "control" && controlEditing);
    }

    function railExtraOf(id) {
        return railOn(id) ? DeckPlan.railExtra(geom) : 0;
    }

    // A page's body size: its own size plus the rail's room when the rail shows.
    function sizeOf(id) {
        const type = pageType(id);
        if (type === "control" && controlEditing)
            return { "w": geom.controlEditW, "h": geom.controlEditH };
        const size = DeckPlan.pageSize(type, geom);
        size.w += railExtraOf(id);
        const fit = id === "live" && deckVisible ? LiveLayout.fitHeight(liveLayout, {
                                                                        "smallH": geom.cellH,
                                                                        "tallH": geom.cellH * 2,
                                                                        "chrome": liveChrome,
                                                                        "headerH": geom.liveHeaderH,
                                                                        "rowH": geom.liveRowH,
                                                                        "gap": geom.liveGap,
                                                                        "mediaGap": geom.liveMediaGap
                                                                    }) : null;
        return fit === null ? size : { "w": size.w, "h": fit };
    }

    function open(intent) {
        current = DeckPlan.entryPage(cycle, lastUsed, intent);
    }

    function goTo(id) {
        current = id;
    }

    onCurrentChanged: lastUsed = current
    // Live appearing adds its rail glyph and stays put; Live emptying moves on to the next page (or the Control Center).
    onCycleChanged: {
        current = DeckPlan.reconcile(previousCycle.length > 0 ? previousCycle : cycle, cycle, current);
        previousCycle = cycle;
    }
    Component.onCompleted: previousCycle = cycle
}
