pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter/Tokens.js" as T
import "../logic/DeckPlan.js" as DeckPlan

// The deck host (D-51): shows the viewed page and moves to the next, sliding sideways and cross-fading. Only the viewed
// page and, during a transition, the pages still leaving exist (P9, at most three). A page keeps its own size and sits centred in the
// silhouette, which morphs around it. The page-control capsule is a satellite outside the island (DeckCapsule).
Item {
    id: deck

    required property var app
    // The PopupContent, for the content insets of a page (they differ for the Control Center) and reduced motion.
    required property var popup
    required property Component controlPage

    // The slot holding the viewed page. Up to two more hold pages still leaving: a new target during a transition
    // retargets from where it is (the arriving page turns round and leaves from its current opacity) instead of queueing.
    property var target: slotA
    readonly property var slots: [slotA, slotB, slotC]

    function componentFor(id) {
        return id === "live" ? liveComponent : id === "control" ? deck.controlPage : presetComponent;
    }

    function sameSize(a, b) {
        const x = deck.app.deck.sizeOf(a);
        const y = deck.app.deck.sizeOf(b);
        return x.w === y.w && x.h === y.h;
    }

    function start(id) {
        const from = deck.target.pageId;
        if (from === "") {
            deck.target.place(id);
            return;
        }
        const dir = DeckPlan.direction(deck.app.deck.cycle, from, id);
        // While scrubbing, a change between pages of one size is a pop (no morph happens, so no slide either).
        const pop = deck.app.deck.scrubbing && !deck.popup.reduceMotion && deck.sameSize(from, id);
        let next = null;
        for (const slot of deck.slots) {
            if (slot !== deck.target && slot.pageId === "") {
                next = slot;
                break;
            }
            if (slot !== deck.target && (next === null || slot.shown < next.shown))
                next = slot;
        }
        if (next !== deck.target)
            deck.target.leave(dir, pop);
        next.arrive(id, dir, pop);
        deck.target = next;
    }

    Component.onCompleted: deck.target.place(deck.app.deck.current)

    Connections {
        function onCurrentChanged() {
            deck.start(deck.app.deck.current);
        }

        target: deck.app.deck
    }

    component Slot: Item {
        id: slot

        property string pageId
        // 1 fully shown. The slot arrives (want 1) or leaves (want 0); each change animates `shown` from where it is.
        property real shown: 1
        property real want: 0
        property int dir: 1
        property bool pop: false
        readonly property bool isControl: pageId === "control"
        readonly property var size: pageId === "" ? ({ "w": 0, "h": 0 }) : deck.app.deck.sizeOf(pageId)
        readonly property var ins: deck.popup.insets(isControl)

        function place(id) {
            move.stop();
            slot.pageId = id;
            slot.shown = 1;
            slot.want = 1;
        }

        function arrive(id, direction, popMode) {
            move.stop();
            slot.pageId = id;
            slot.dir = direction;
            slot.pop = popMode;
            slot.shown = 0;
            slot.want = 1;
            move.restart();
        }

        function leave(direction, popMode) {
            slot.dir = direction;
            slot.pop = popMode;
            slot.want = 0;
            move.restart();
        }

        x: (deck.width - size.w) / 2 + ins.l
        y: ins.t
        width: size.w - ins.l - ins.r
        height: size.h - ins.t - ins.b
        opacity: shown
        visible: opacity > 0 && pageId !== ""
        scale: slot.pop ? T.scrubPopScale + (1 - T.scrubPopScale) * slot.shown : 1
        transform: Translate {
            // The page leaves toward one side and its successor arrives from the other.
            x: deck.popup.reduceMotion || slot.pop ? 0 : (slot.want === 0 ? -1 : 1) * slot.dir * T.deckSlideDistance * (1 - slot.shown)
        }

        NumberAnimation {
            id: move

            target: slot
            property: "shown"
            to: slot.want
            duration: slot.pop ? T.scrubPopMs : deck.popup.reduceMotion ? T.motionFast : T.motionPage
            easing.type: T.easingStandard
            onFinished: {
                if (slot.want === 0)
                    slot.pageId = "";
            }
        }

        Loader {
            id: loader

            anchors.fill: parent
            active: slot.pageId !== ""
            sourceComponent: deck.componentFor(slot.pageId)
        }

        Binding {
            target: loader.item
            property: "pageId"
            value: slot.pageId
            when: loader.item !== null && slot.pageId !== "live" && slot.pageId !== "control"
            restoreMode: Binding.RestoreNone
        }
    }

    Slot {
        id: slotA
    }

    Slot {
        id: slotB
    }

    Slot {
        id: slotC
    }

    Component {
        id: liveComponent

        LivePage {
            app: deck.app
        }
    }

    Component {
        id: presetComponent

        PresetPage {
            app: deck.app
        }
    }
}
