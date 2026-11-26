import QtQuick
import QtTest
import "../contents/ui/shell" as Shell
import "../contents/ui/services" as Services
import "../contents/ui/logic/WidgetRegistry.js" as Registry
import "../contents/ui/widgets/Manifests.js" as Manifests

// D-69: the welcome tour page. Its stepper, the footer's buttons per step, Skip and Done, and the opt-in example page with
// its refusals. The words are faked as their keys; the real strings are checked by the lint and the Node tests.
Item {
    id: testRoot

    width: 700
    height: 140

    property var versions: []
    property var stored: []
    property var pages: []

    QtObject {
        id: strings

        function tourTitle(id) { return padded ? "title:" + id + " with a very long translated title that cannot fit on one line at all" : "title:" + id; }
        property bool padded: false
        function tourBody(id) { return padded ? "body:" + id + " " + "a long translated sentence that keeps going ".repeat(12) : "body:" + id; }
        function tourCounter(n, total) { return n + " of " + total; }
        function tourExampleHint(state) { return state === "ready" || state === "exists" ? "" : "hint:" + state + (padded ? " and a very long translated explanation of why" : ""); }
        readonly property string tourSkip: "Skip"
        readonly property string tourBack: "Back"
        readonly property string tourNext: "Next"
        readonly property string tourDone: "Done"
        readonly property string tourAddExample: "Add an example page"
        readonly property string tourShowExample: "Show the example page"
    }

    Services.TourState {
        id: tour

        storedVersion: 0
        storedPresets: ""
        presetsLocked: false
        draftKept: false
        registry: Registry.build(Manifests.list)
        onVersionRequested: version => testRoot.versions.push(version)
        onPresetsRequested: json => testRoot.stored.push(json)
        onPageRequested: id => testRoot.pages.push(id)
    }

    QtObject {
        id: app

        readonly property var tour: tour
        readonly property var strings: strings
        property bool reduceMotion: true
    }

    Shell.WelcomePage {
        id: page

        width: 656
        height: 96
        app: app
    }

    TestCase {
        name: "WelcomePage"
        when: windowShown

        function init() {
            tour.storedVersion = 0;
            tour.storedPresets = "";
            tour.presetsLocked = false;
            tour.draftKept = false;
            app.reduceMotion = true;
            tour.step = 0;
            testRoot.versions = [];
            testRoot.stored = [];
            testRoot.pages = [];
        }

        function all(item, out) {
            out = out || [];
            for (const child of item.children) {
                out.push(child);
                all(child, out);
            }
            return out;
        }

        function button(name) {
            return all(page).find(item => item.Accessible && item.Accessible.name === name && item.visible) || null;
        }

        // A Row positions its children when the next frame polishes it, so wait for one after any state change; then a move
        // first, as a real pointer does, so the handlers see the pointer arrive before the press.
        function tap(item) {
            waitForRendering(page);
            mouseMove(item, item.width / 2, item.height / 2);
            mouseClick(item, item.width / 2, item.height / 2);
        }

        function text(value) {
            return all(page).find(item => item.text === value && item.visible) || null;
        }

        function preset(id, name) {
            return { "id": id, "name": name || "", "inCycle": true, "page": "small", "placements": [{ "pid": "x" + id, "widget": "clock", "span": "1x1", "settings": {} }] };
        }

        function test_firstStep() {
            verify(text("title:island"));
            verify(text("body:island"));
            verify(text("1 of 5"));
            verify(button("Next"));
            verify(button("Skip"));
            compare(button("Back"), null);
            compare(button("Add an example page"), null);
        }

        function test_nextAndBack() {
            tap(button("Next"));
            verify(text("title:live"));
            verify(text("2 of 5"));
            verify(button("Back"));
            tap(button("Back"));
            verify(text("title:island"));
            compare(button("Back"), null);
        }

        function test_lastStepHasDoneAndNoSkip() {
            for (let i = 0; i < 4; ++i)
                tap(button("Next"));
            verify(text("5 of 5"));
            verify(text("title:gestures"));
            compare(button("Next"), null);
            compare(button("Skip"), null);
            verify(button("Done"));
            tap(button("Done"));
            compare(testRoot.versions.length, 1);
            compare(testRoot.versions[0], 1);
        }

        function test_skipStoresTheVersion() {
            tap(button("Skip"));
            compare(testRoot.versions.length, 1);
            compare(testRoot.versions[0], 1);
        }

        function test_exampleButtonOnlyOnItsStep() {
            for (let i = 0; i < 3; ++i) {
                compare(button("Add an example page"), null);
                tap(button("Next"));
            }
            verify(text("title:customize"));
            verify(button("Add an example page"));
        }

        function test_addExampleStoresOnePageAndGoesToIt() {
            tour.step = 3;
            tap(button("Add an example page"));
            compare(testRoot.stored.length, 1);
            compare(testRoot.pages.length, 1);
            const blob = JSON.parse(testRoot.stored[0]);
            compare(blob.presets.length, 1);
            compare(blob.presets[0].name, "Essentials");
            compare(blob.presets[0].page, "wide");
            compare(blob.presets[0].placements.length, 4);
            compare(testRoot.pages[0], blob.presets[0].id);
        }

        function test_withTheExamplePageTheButtonOnlyGoesToIt() {
            tour.storedPresets = JSON.stringify({ "format": 2, "presets": [preset("p1"), preset("p2", "Essentials")] });
            tour.step = 3;
            verify(button("Show the example page"));
            compare(button("Add an example page"), null);
            tap(button("Show the example page"));
            compare(testRoot.stored.length, 0);
            compare(testRoot.pages.length, 1);
            compare(testRoot.pages[0], "p2");
        }

        function test_atTheCapTheButtonIsDisabledWithAHint() {
            tour.storedPresets = JSON.stringify({ "format": 2, "presets": [preset("p1"), preset("p2"), preset("p3")] });
            tour.step = 3;
            const add = button("Add an example page");
            verify(add);
            compare(add.enabled, false);
            verify(text("hint:cap"));
            tap(add);
            compare(testRoot.stored.length, 0);
            compare(testRoot.pages.length, 0);
        }

        function test_refusalsShowTheirHint() {
            tour.step = 3;
            tour.presetsLocked = true;
            verify(text("hint:locked"));
            tour.presetsLocked = false;
            tour.draftKept = true;
            verify(text("hint:draft"));
            tour.draftKept = false;
            tour.storedPresets = "{nope";
            verify(text("hint:unreadable"));
        }

        function test_longTextStaysInsideTheCard() {
            strings.padded = true;
            tour.storedPresets = JSON.stringify({ "format": 2, "presets": [preset("p1"), preset("p2"), preset("p3")] });
            for (let step = 0; step < 5; ++step) {
                tour.step = step;
                waitForRendering(page);
                const body = all(page).find(item => typeof item.text === "string" && item.text.indexOf("body:") === 0);
                const title = all(page).find(item => typeof item.text === "string" && item.text.indexOf("title:") === 0);
                const last = button(step === 4 ? "Done" : "Next");
                verify(body.lineCount <= 2, "body lines at step " + step);
                compare(title.lineCount, 1);
                verify(body.mapToItem(page, 0, body.height).y <= last.mapToItem(page, 0, 0).y, "body clears the buttons at step " + step);
                verify(body.mapToItem(page, body.width, 0).x <= page.width, "body inside at step " + step);
                const leftmost = all(page).filter(item => item.Accessible && item.Accessible.role === Accessible.Button && item.visible).reduce((min, item) => Math.min(min, item.mapToItem(page, 0, 0).x), page.width);
                const counter = all(page).find(item => item.text === (step + 1) + " of 5");
                verify(counter.mapToItem(page, counter.width, 0).x <= leftmost, "counter clear of the buttons at step " + step);
                const hint = all(page).find(item => typeof item.text === "string" && item.text.indexOf("hint:") === 0 && item.visible);
                if (hint)
                    verify(hint.mapToItem(page, 0, 0).x >= counter.mapToItem(page, counter.width, 0).x, "hint clear of the counter");
            }
            strings.padded = false;
        }

        function test_aStepChangeFadesAndSwapsThenNothingRuns() {
            const swap = findChild(page, "swap");
            const card = findChild(page, "card");
            verify(swap);
            verify(card);
            app.reduceMotion = false;
            tour.step = 1;
            verify(swap.running, "the swap runs on a change");
            tryVerify(() => !swap.running, 2000, "and ends");
            verify(text("title:live"));
            compare(card.opacity, 1);
            compare(card.transform[0].x, 0);
            wait(300);
            verify(!swap.running, "nothing runs while a card sits");
        }

        function test_theCounterIsCentredUnderTheIcon() {
            const counter = all(page).find(item => item.text === "1 of 5");
            const tile = all(page).find(item => item.width === 44 && item.height === 44);
            verify(counter);
            verify(tile);
            const tileCentre = tile.mapToItem(page, tile.width / 2, 0).x;
            const counterCentre = counter.mapToItem(page, counter.width / 2, 0).x;
            verify(Math.abs(tileCentre - counterCentre) <= 1, "counter centre " + counterCentre + " vs icon " + tileCentre);
            compare(tile.mapToItem(page, 0, 0).x, 0, "the icon stays where it was");
        }

        function test_reducedMotionSwapsAtOnce() {
            const swap = findChild(page, "swap");
            tour.step = 2;
            verify(!swap.running);
            verify(text("title:deck"));
        }

        function test_retakeRestartsTheTourAndGoesToWelcome() {
            tour.storedVersion = 1;
            tour.step = 3;
            tour.retake();
            compare(tour.step, 0);
            compare(testRoot.versions.length, 1);
            compare(testRoot.versions[0], 0);
            compare(testRoot.pages.length, 1);
            compare(testRoot.pages[0], "welcome");
        }

        function test_aReplayStartsFromTheFirstStep() {
            tour.storedVersion = 1;
            compare(tour.pending, false);
            tour.step = 3;
            tour.storedVersion = 0;
            compare(tour.pending, true);
            compare(tour.step, 0);
            verify(text("title:island"));
        }
    }
}
