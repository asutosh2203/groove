pragma ComponentBehavior: Bound

import QtQuick
import "../logic/Accordion.js" as Accordion
import "../logic/DeckPlan.js" as DeckPlan
import "../logic/LiveGlyphs.js" as LiveGlyphs
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
    required property string liveMediaKind
    required property var liveJobs
    // The presets that show, from PresetStore.
    required property var presets
    required property bool editing
    // The preset editor's body size while it is open (D-56), else null.
    property var editSize: null
    required property var geom

    property string current: "control"
    property string lastUsed: ""
    property var previousCycle: []

    readonly property var cycle: DeckPlan.buildCycle(liveCount > 0, presets)
    // Edit mode (zoom included) is pre-sized with the cycle, so entering it never resizes the window (D-43).
    readonly property var windowSize: {
        const deck = DeckPlan.windowSize(cycle, geom);
        const edit = DeckPlan.editWindow(geom);
        return { "w": Math.max(deck.w, edit.w), "h": Math.max(deck.h, edit.h) };
    }
    readonly property var liveLayout: LiveLayout.layout({ "hasMedia": deckVisible && liveMedia, "jobs": deckVisible ? liveJobs : [] })
    readonly property int liveShownCount: deckVisible ? liveLayout.count : liveCount
    // The job row opened in place in the list (accordion); per session, reset when the deck closes.
    property string openJobId: ""
    readonly property string openJob: Accordion.clamp(openJobId, liveLayout.jobs.map(job => job.id))
    // What the capsule's Live item shows follows what the Live page shows.
    // A string, so the capsule only hears about a real change (the layout is rebuilt on every progress tick).
    readonly property string liveGlyphKind: LiveGlyphs.liveKind(liveLayout.mediaSlot, liveMediaKind, liveLayout.jobs.map(job => job.kind))
    readonly property var liveGlyphs: LiveGlyphs.chain(liveGlyphKind)
    readonly property var indicator: DeckPlan.indicator(cycle, current, liveGlyphs)

    // A preset page's data (name, type, placements), or null for Live and the Control Center.
    function presetFor(id) {
        return presets.find(preset => preset.id === id) || null;
    }

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

    // The capsule shows with two or more pages, except while editing (D-56: the chips bar is the navigator).
    readonly property bool capsuleWanted: cycle.length > 1 && !editing

    // A page's body size.
    function sizeOf(id) {
        if (editSize !== null)
            return editSize;
        const type = pageType(id);
        const size = DeckPlan.pageSize(type, geom);
        const fit = id === "live" && deckVisible ? LiveLayout.fitHeight(liveLayout, {
                                                                        "smallH": geom.cellH,
                                                                        "tallH": geom.cellH * 2,
                                                                        "chrome": liveChrome,
                                                                        "headerH": geom.liveHeaderH,
                                                                        "rowH": geom.liveRowH,
                                                                        "gap": geom.liveGap,
                                                                        "mediaGap": geom.liveMediaGap,
                                                                        "expandedExtra": openJob !== "" ? geom.liveTileH - geom.liveRowH : 0
                                                                    }) : null;
        return fit === null ? size : { "w": size.w, "h": fit };
    }

    function open(intent) {
        current = DeckPlan.entryPage(cycle, lastUsed, intent);
    }

    function goTo(id) {
        current = id;
    }

    function toggleJob(id) {
        openJobId = Accordion.toggle(openJob, id);
    }

    onDeckVisibleChanged: {
        if (!deckVisible)
            openJobId = "";
    }

    onCurrentChanged: lastUsed = current
    // Live appearing adds its capsule glyph and stays put; Live emptying moves on to the next page (or the Control Center).
    onCycleChanged: {
        current = DeckPlan.reconcile(previousCycle.length > 0 ? previousCycle : cycle, cycle, current);
        previousCycle = cycle;
    }
    Component.onCompleted: previousCycle = cycle
}
