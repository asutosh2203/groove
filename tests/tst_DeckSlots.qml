import QtQuick
import QtTest
import "../contents/ui/shell" as Shell

// D-62: a new page target during a transition retargets, and at rest only the viewed page exists (P9).
Item {
    id: testRoot

    width: 400
    height: 300

    QtObject {
        id: app

        property bool scrubbing: false
        readonly property var deck: QtObject {
            id: deck

            property string current: "a"
            property bool scrubbing: false
            readonly property var cycle: [{ "id": "a" }, { "id": "b" }, { "id": "c" }, { "id": "control" }]
            function sizeOf(id) { return id === "c" ? { "w": 300, "h": 200 } : { "w": 300, "h": 100 }; }
            function presetFor(id) { return null; }
        }
    }

    QtObject {
        id: popup

        readonly property bool reduceMotion: false
        function insets(isControl) { return { "l": 0, "r": 0, "t": 0, "b": 0 }; }
    }

    Component {
        id: controlPage

        Item {
            property string pageId
        }
    }

    Shell.Deck {
        id: host

        width: 400
        height: 300
        app: app
        popup: popup
        controlPage: controlPage
    }

    TestCase {
        name: "DeckSlots"
        when: windowShown

        function pages() { return host.slots.filter(s => s.pageId !== ""); }
        function loaders() {
            let n = 0;
            for (const slot of host.slots) {
                for (const child of slot.children) {
                    if (child.active === true)
                        ++n;
                }
            }
            return n;
        }

        function test_at_rest_only_the_current_page_exists() {
            compare(pages().length, 1);
            compare(loaders(), 1);
            deck.current = "b";
            compare(pages().length, 2);
            deck.current = "c";
            deck.current = "control";
            verify(pages().length >= 2);
            verify(pages().length <= 3);
            tryVerify(() => pages().length === 1, 2000);
            compare(pages()[0].pageId, "control");
            compare(loaders(), 1);
            compare(host.target.pageId, "control");
            fuzzyCompare(host.target.shown, 1, 0.001);
        }

        function test_retarget_keeps_the_arriving_page_fading_out_instead_of_snapping() {
            deck.current = "a";
            tryVerify(() => pages().length === 1, 2000);
            deck.current = "b";
            wait(80);
            const mid = host.target.shown;
            verify(mid > 0 && mid < 1);
            const arriving = host.target;
            deck.current = "c";
            verify(arriving.pageId === "b");
            verify(arriving.want === 0);
            verify(Math.abs(arriving.shown - mid) < 0.5);
            tryVerify(() => pages().length === 1, 2000);
            compare(pages()[0].pageId, "c");
        }
    }
}
