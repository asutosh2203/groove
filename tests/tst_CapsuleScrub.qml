import QtQuick
import QtTest
import "../contents/ui/shell" as Shell
import "../contents/ui/controlcenter/Tokens.js" as T

// D-62: the capsule scrub, driven with synthetic press/move/release.
Item {
    id: testRoot

    width: 400
    height: 200

    QtObject {
        id: app

        property var log: []
        readonly property real rimLight: 0
        readonly property var strings: QtObject {
            readonly property string deckLive: "Live"
            readonly property string deckControlCenter: "Control Center"
            function deckPage(id) { return id; }
        }
        readonly property var deck: QtObject {
            id: deck

            property bool scrubbing: false
            property string current: "live"
            readonly property var cycle: [{ "id": "live" }, { "id": "a" }, { "id": "b" }, { "id": "c" }, { "id": "control" }]
            readonly property var indicator: [
                { "id": "live", "kind": "glyph", "glyphs": ["media-playback-start-symbolic"] },
                { "id": "a", "kind": "dot", "glyphs": [] },
                { "id": "b", "kind": "dot", "glyphs": [] },
                { "id": "c", "kind": "dot", "glyphs": [] },
                { "id": "control", "kind": "glyph", "glyphs": ["configure-symbolic"] }
            ]
            function goTo(id) {
                app.log = app.log.concat([id]);
                deck.current = id;
            }
        }
    }

    // Stands in for the popup's window-wide click handler (an outside click closes the deck).
    MouseArea {
        id: outside

        property int clicks: 0

        anchors.fill: parent
        onClicked: outside.clicks++
    }

    Shell.DeckCapsule {
        id: capsule

        x: 100
        y: 100
        app: app
        control: false
        reduceMotion: false
    }

    TestCase {
        name: "CapsuleScrub"
        when: windowShown

        // Item centres in testRoot coordinates: 8 pad + 11, then every 22.
        function cx(i) { return capsule.x + 19 + 22 * i; }
        readonly property real cy: 115

        function init() {
            app.log = [];
            deck.current = "live";
            deck.scrubbing = false;
            outside.clicks = 0;
            capsule.enabled = true;
            capsule.scrubDwell = 0;
        }

        function test_click_navigates() {
            mouseClick(testRoot, cx(2), cy);
            compare(app.log.join(), "b");
            compare(outside.clicks, 0);
        }

        function test_click_on_the_body_does_nothing() {
            mouseClick(testRoot, capsule.x + 3, cy);
            compare(app.log.length, 0);
            compare(outside.clicks, 0);
        }

        function test_live_scrub_switches_each_crossing_in_order() {
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(1), cy);
            mouseMove(testRoot, cx(2), cy);
            mouseMove(testRoot, cx(3), cy);
            compare(app.log.join(), "a,b,c");
            verify(deck.scrubbing);
            mouseRelease(testRoot, cx(3), cy);
            compare(app.log.join(), "a,b,c");
            verify(!deck.scrubbing);
        }

        function test_dwell_fast_cross_switches_once_on_release() {
            capsule.scrubDwell = 120;
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(1), cy);
            mouseMove(testRoot, cx(2), cy);
            mouseMove(testRoot, cx(3), cy);
            compare(app.log.length, 0);
            mouseRelease(testRoot, cx(3), cy);
            compare(app.log.join(), "c");
        }

        function test_dwell_rest_switches_before_release() {
            capsule.scrubDwell = 60;
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(2), cy);
            wait(150);
            compare(app.log.join(), "b");
            mouseRelease(testRoot, cx(2), cy);
            compare(app.log.join(), "b");
        }

        function test_release_far_outside_commits_the_last_item_and_is_not_a_click() {
            mousePress(testRoot, cx(3), cy);
            mouseMove(testRoot, cx(4), cy);
            mouseMove(testRoot, 390, 190);
            mouseRelease(testRoot, 390, 190);
            compare(app.log.join(), "control");
            compare(outside.clicks, 0);
        }

        function test_vertical_drift_is_ignored_and_ends_clamp() {
            deck.current = "b";
            mousePress(testRoot, cx(2), cy);
            mouseMove(testRoot, cx(2) - 90, cy + 80);
            mouseRelease(testRoot, cx(2) - 90, cy + 80);
            compare(app.log.join(), "live");
        }

        function test_popin_mid_scrub_cancels_without_committing() {
            capsule.scrubDwell = 120;
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(3), cy);
            capsule.enabled = false;
            verify(!deck.scrubbing);
            mouseRelease(testRoot, cx(3), cy);
            wait(200);
            compare(app.log.length, 0);
            compare(deck.current, "live");
        }

        function test_delegates_are_not_recreated_during_a_scrub() {
            const row = capsule.children[2];
            const before = [];
            for (let i = 0; i < row.children.length; ++i)
                before.push(row.children[i]);
            compare(before.length, 6);
            mousePress(testRoot, cx(0), cy);
            for (let i = 1; i < 5; ++i)
                mouseMove(testRoot, cx(i), cy);
            mouseRelease(testRoot, cx(4), cy);
            for (let i = 0; i < before.length; ++i)
                verify(row.children[i] === before[i]);
        }

        // Hover-brighten stays on the items' HoverHandler (the per-item click areas are gone).
        function test_item_hover_brightens_and_is_off_while_scrubbing() {
            const entries = [];
            const kids = capsule.children[2].children;
            for (let i = 0; i < kids.length; ++i) {
                if (kids[i].tone !== undefined)
                    entries.push(kids[i]);
            }
            compare(entries.length, 5);
            mouseMove(testRoot, 5, 5);
            tryVerify(() => Qt.colorEqual(entries[2].tone, T.textTertiary));
            mouseMove(testRoot, cx(2) - 5, cy);
            mouseMove(testRoot, cx(2), cy);
            tryVerify(() => Qt.colorEqual(entries[2].tone, T.textSecondary));
            mousePress(testRoot, cx(2), cy);
            mouseMove(testRoot, cx(3), cy);
            verify(capsule.scrubbing);
            mouseRelease(testRoot, cx(3), cy);
            mouseMove(testRoot, 5, 5);
            tryVerify(() => Qt.colorEqual(entries[2].tone, T.textTertiary));
        }

        function test_swell_while_scrubbing_and_settles_after() {
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(2), cy);
            tryVerify(() => capsule.scale > 1.05);
            mouseRelease(testRoot, cx(2), cy);
            tryVerify(() => capsule.scale === 1);
        }

        function test_reduced_motion_switches_on_release_only_and_does_not_swell() {
            capsule.reduceMotion = true;
            mousePress(testRoot, cx(0), cy);
            mouseMove(testRoot, cx(3), cy);
            compare(app.log.length, 0);
            compare(capsule.scale, 1);
            mouseRelease(testRoot, cx(3), cy);
            compare(app.log.join(), "c");
            capsule.reduceMotion = false;
        }
    }
}
