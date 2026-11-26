pragma ComponentBehavior: Bound

import QtQuick
import "../logic/StarterPresets.js" as StarterPresets
import "../logic/Tour.js" as Tour

// The welcome tour's state (D-69), one per island: whether it is pending, the step being shown (kept while the deck is
// closed) and the opt-in example page. The decisions are pure (logic/Tour.js, logic/StarterPresets.js); what leaves
// here is a signal, so the config keys and the deck stay main.qml's to write.
QtObject {
    id: tour

    required property int storedVersion
    required property string storedPresets
    required property bool presetsLocked
    required property bool draftKept
    required property var registry

    signal versionRequested(int version)
    signal presetsRequested(string json)
    signal pageRequested(string id)

    property int step: 0
    readonly property bool pending: Tour.shouldShow({ "tourVersion": tour.storedVersion })
    readonly property var view: Tour.view(tour.step)
    // { state, id }: whether the example page can be added, exists, or why not (StarterPresets.status).
    readonly property var example: StarterPresets.status(tour.storedPresets, tour.registry, { "locked": tour.presetsLocked, "draftKept": tour.draftKept })

    function next() {
        tour.step = Tour.next(tour.step);
    }

    function back() {
        tour.step = Tour.back(tour.step);
    }

    // Done and Skip both end the tour for this version.
    function finish() {
        tour.versionRequested(Tour.version());
    }

    // The Control Center's button: starts the tour over and goes to its page.
    function retake() {
        tour.step = 0;
        tour.versionRequested(0);
        tour.pageRequested("welcome");
    }

    // Adds the page when it is absent, then asks the deck to show it; with the page already there it only goes to it.
    function addExample() {
        const result = StarterPresets.add(tour.storedPresets, tour.registry, { "locked": tour.presetsLocked, "draftKept": tour.draftKept });
        if (result.state === "added")
            tour.presetsRequested(result.json);
        if (result.state === "added" || result.state === "exists")
            tour.pageRequested(result.id);
        return result.state;
    }

    // A replay starts from the first step.
    onPendingChanged: {
        if (tour.pending)
            tour.step = 0;
    }
}
