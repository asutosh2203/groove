import QtQuick
import QtTest
import "../contents/ui/services" as Services

// D-69: the deck opens on Welcome the first time a click opens it while the tour is pending, never for a double click, and
// goes back to the usual entry once Welcome was seen; a replay brings it back and Done moves the viewer on.
Item {
    id: testRoot

    width: 100
    height: 100

    Services.DeckState {
        id: deck

        liveCount: 0
        deckVisible: false
        liveMedia: false
        liveMediaKind: "music"
        liveJobs: []
        liveAgents: []
        liveTimers: []
        presets: [{ "id": "p1", "name": "", "type": "small", "inCycle": true, "placements": [] }]
        editing: false
        tourPending: true
        geom: ({ "cellW": 170, "cellH": 120, "padding": 12, "capsuleExtra": 37, "capsuleW": 148, "controlW": 430, "controlH": 540, "controlEditW": 620, "controlEditH": 570 })
    }

    TestCase {
        name: "TourEntry"
        when: windowShown

        function init() {
            deck.tourPending = false;
            deck.tourPending = true;
            deck.current = "control";
            deck.lastUsed = "";
        }

        function ids() { return deck.cycle.map(page => page.id); }

        function test_welcomeIsInTheCycleWhilePending() {
            compare(ids().join(","), "welcome,p1,control");
            deck.tourPending = false;
            compare(ids().join(","), "p1,control");
        }

        function test_aClickOpensWelcomeOnce() {
            deck.open("click");
            compare(deck.current, "welcome");
            deck.goTo("control");
            deck.open("click");
            compare(deck.current, "control", "the usual entry once Welcome was seen");
        }

        function test_aDoubleClickStillOpensTheControlCenter() {
            deck.open("double");
            compare(deck.current, "control");
            verify(!deck.welcomeSeen);
        }

        function test_aReplayBringsWelcomeFirstAgain() {
            deck.open("click");
            deck.goTo("control");
            deck.tourPending = false;
            deck.tourPending = true;
            deck.open("click");
            compare(deck.current, "welcome");
        }

        function test_doneWhileViewingMovesOn() {
            deck.open("click");
            compare(deck.current, "welcome");
            deck.tourPending = false;
            compare(deck.current, "p1");
        }

        function test_retakeJumpsToWelcomeOnceItIsInTheCycle() {
            deck.tourPending = false;
            deck.goTo("control");
            deck.tourPending = true;
            deck.goTo("welcome");
            compare(deck.current, "welcome");
            verify(deck.welcomeSeen);
            compare(deck.pageType("welcome"), "wide");
        }

        function test_withoutThePendingTourNothingChanges() {
            deck.tourPending = false;
            deck.open("click");
            compare(deck.current, "p1");
        }

        function test_theWelcomePageIsWide() {
            compare(deck.sizeOf("welcome").w, 680);
            compare(deck.sizeOf("welcome").h, 120);
        }
    }
}
