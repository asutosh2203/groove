pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/DeckPlan.js" as DeckPlan

// The deck host (D-51): shows the viewed page and moves to the next along the rail, sliding and cross-fading. Only the
// viewed page and, during a transition, the outgoing one exist (P9). A page keeps its own size and sits centred in the
// silhouette, which morphs around it. The rail is a vertical column of glyphs inside the island's right edge.
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
    // +1: the new page is lower on the rail, so content slides up; -1: it is higher, so content slides down.
    property int slideDir: 1
    readonly property var rail: deck.app.deck.indicator
    readonly property bool railShown: deck.rail !== null && deck.app.deck.railOn(deck.app.deck.current)

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
        width: size.w - (pageId === "" ? 0 : deck.app.deck.railExtraOf(pageId)) - ins.l - ins.r
        height: size.h - ins.t - ins.b
        opacity: shown
        visible: opacity > 0 && pageId !== ""
        transform: Translate {
            // The page moves along the rail's axis: it leaves toward one end and its successor arrives from the other.
            y: deck.popup.reduceMotion ? 0 : (slot === deck.front ? -deck.slideDir * T.deckSlideDistance * (1 - slot.shown) : deck.slideDir * T.deckSlideDistance * (1 - slot.shown))
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

    // The rail: one glyph per page in deck order, vertically centred in the page. The current page's glyph is full white,
    // the others a muted neutral that brightens on hover (lightness only, D-45).
    Column {
        id: railColumn

        x: deck.width - deck.popup.earSide - deck.popup.insets(deck.app.deck.current === "control").r - T.deckRailWidth
        anchors.verticalCenter: parent.verticalCenter
        opacity: deck.railShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        Repeater {
            model: deck.rail

            delegate: Item {
                id: mark

                required property var modelData

                width: T.deckRailWidth
                height: T.deckRailWidth
                Accessible.role: Accessible.Button
                Accessible.name: mark.modelData.id === "live" ? deck.app.strings.deckLive : mark.modelData.id === "control" ? deck.app.strings.deckControlCenter : deck.app.strings.deckPage(mark.modelData.id)

                CC.ThemeGlyph {
                    anchors.centerIn: parent
                    width: T.deckRailGlyph
                    height: T.deckRailGlyph
                    names: mark.modelData.glyphs
                    color: mark.modelData.current ? T.textPrimary : hover.hovered ? T.textSecondary : T.textTertiary

                    Behavior on color {
                        enabled: !deck.popup.reduceMotion

                        ColorAnimation {
                            duration: T.motionHover
                            easing.type: T.easingStandard
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: deck.app.deck.goTo(mark.modelData.id)
                }
            }
        }
    }
}
