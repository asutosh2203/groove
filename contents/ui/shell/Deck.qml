pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter/Tokens.js" as T
import "../logic/DeckPlan.js" as DeckPlan

// The deck host (D-51): shows the viewed page and moves to the next, sliding sideways and cross-fading. Only the viewed
// page and, during a transition, the outgoing one exist (P9). A page keeps its own size and sits centred in the
// silhouette, which morphs around it. The page-control capsule is a satellite outside the island (DeckCapsule).
Item {
    id: deck

    required property var app
    // The PopupContent, for the content insets of a page (they differ for the Control Center) and reduced motion.
    required property var popup
    required property Component controlPage

    property var front: slotA
    property var back: slotB
    property real fade: 0
    property bool fading: false
    // +1: the new page is further right in the capsule, so content slides left; -1: further left, so content slides right.
    property int slideDir: 1

    function componentFor(id) {
        return id === "live" ? liveComponent : id === "control" ? deck.controlPage : dummyComponent;
    }

    function start(id) {
        if (deck.fading)
            deck.finish();
        if (deck.front.pageId === "") {
            deck.front.pageId = id;
            return;
        }
        deck.slideDir = DeckPlan.direction(deck.app.deck.cycle, deck.front.pageId, id);
        deck.back.pageId = id;
        deck.fading = true;
        fadeAnimation.restart();
    }

    function finish() {
        fadeAnimation.stop();
        deck.front.pageId = "";
        const old = deck.front;
        deck.front = deck.back;
        deck.back = old;
        deck.fading = false;
        deck.fade = 0;
    }

    Component.onCompleted: deck.front.pageId = deck.app.deck.current

    Connections {
        function onCurrentChanged() {
            deck.start(deck.app.deck.current);
        }

        target: deck.app.deck
    }

    NumberAnimation {
        id: fadeAnimation

        target: deck
        property: "fade"
        from: 0
        to: 1
        duration: deck.popup.reduceMotion ? T.motionFast : T.motionPage
        easing.type: T.easingStandard
        onFinished: deck.finish()
    }

    component Slot: Item {
        id: slot

        property string pageId
        // 1 when this slot is the one fully shown, 0 when it is the one arriving or leaving at the far end.
        property real shown: 1
        readonly property bool isControl: pageId === "control"
        readonly property var size: pageId === "" ? ({ "w": 0, "h": 0 }) : deck.app.deck.sizeOf(pageId)
        readonly property var ins: deck.popup.insets(isControl)

        x: (deck.width - size.w) / 2 + ins.l
        y: ins.t
        width: size.w - ins.l - ins.r
        height: size.h - ins.t - ins.b
        opacity: shown
        visible: opacity > 0 && pageId !== ""
        transform: Translate {
            // The page leaves toward one side and its successor arrives from the other.
            x: deck.popup.reduceMotion ? 0 : (slot === deck.front ? -deck.slideDir * T.deckSlideDistance * (1 - slot.shown) : deck.slideDir * T.deckSlideDistance * (1 - slot.shown))
        }

        Loader {
            id: loader

            anchors.fill: parent
            active: slot.pageId !== ""
            sourceComponent: deck.componentFor(slot.pageId)
        }

        Binding {
            target: loader.item
            property: "label"
            value: slot.pageId.replace("dummy-", "") + " " + DeckPlan.cellLabel(slot.pageId.replace("dummy-", ""))
            when: loader.item !== null && slot.pageId.startsWith("dummy-")
            restoreMode: Binding.RestoreNone
        }
    }

    Slot {
        id: slotA

        shown: deck.front === slotA ? (deck.fading ? 1 - deck.fade : 1) : (deck.fading ? deck.fade : 0)
    }

    Slot {
        id: slotB

        shown: deck.front === slotB ? (deck.fading ? 1 - deck.fade : 1) : (deck.fading ? deck.fade : 0)
    }

    Component {
        id: liveComponent

        LivePage {
            app: deck.app
        }
    }

    Component {
        id: dummyComponent

        DummyPage {
        }
    }
}
