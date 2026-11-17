pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import ".."
import "../controlcenter/Tokens.js" as T

// The deck host (D-51): shows the viewed page and cross-fades to the next. Only the viewed page and, during a fade, the
// outgoing one exist (P9). A page keeps its own size and sits centred in the silhouette, which morphs around it.
Item {
    id: deck

    required property var app
    // The PopupContent, for the content insets of a page (they differ for the Control Center).
    required property var popup
    required property Component controlPage

    property var front: slotA
    property var back: slotB
    property real fade: 0
    property bool fading: false
    readonly property var ind: deck.app.deck.indicator

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
        duration: T.motionFade
        onFinished: deck.finish()
    }

    component Slot: Item {
        id: slot

        property string pageId
        readonly property bool isControl: pageId === "control"
        readonly property var size: pageId === "" ? ({ "w": 0, "h": 0 }) : deck.app.deck.sizeOf(pageId)
        readonly property var ins: deck.popup.insets(isControl)

        x: (deck.width - size.w) / 2 + ins.l
        y: ins.t
        width: size.w - ins.l - ins.r
        height: size.h - ins.t - (isControl ? ins.b : Math.max(ins.b, T.deckInset))
        visible: opacity > 0 && pageId !== ""

        Loader {
            id: loader

            anchors.fill: parent
            active: slot.pageId !== ""
            sourceComponent: deck.componentFor(slot.pageId)
        }

        Binding {
            target: loader.item
            property: "label"
            value: slot.pageId.replace("dummy-", "") + " " + slot.size.w / T.deckCellW + "×" + slot.size.h / T.deckCellH
            when: loader.item !== null && slot.pageId.startsWith("dummy-")
            restoreMode: Binding.RestoreNone
        }
    }

    Slot {
        id: slotA

        opacity: deck.front === slotA ? (deck.fading ? 1 - deck.fade : 1) : (deck.fading ? deck.fade : 0)
    }

    Slot {
        id: slotB

        opacity: deck.front === slotB ? (deck.fading ? 1 - deck.fade : 1) : (deck.fading ? deck.fade : 0)
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

    // The bottom strip for the page indicator. Content never extends into it.
    Item {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: T.deckInset

        Row {
            anchors.centerIn: parent
            spacing: T.deckSpacing
            visible: deck.ind !== null

            Repeater {
                model: deck.ind

                delegate: Item {
                    id: mark

                    required property var modelData
                    required property int index

                    width: Math.max(T.deckHit, markWidth + T.deckSpacing * 2)
                    height: T.deckInset
                    readonly property real markWidth: modelData.kind === "pill" ? T.deckPillW : modelData.kind === "gear" ? T.deckGear : T.deckDot
                    opacity: modelData.current ? 1 : T.deckDimOpacity
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.kind === "pill" ? deck.app.strings.deckLive : modelData.kind === "gear" ? deck.app.strings.deckControlCenter : deck.app.strings.deckPage(index + 1)

                    Rectangle {
                        anchors.centerIn: parent
                        visible: mark.modelData.kind !== "gear"
                        width: mark.markWidth
                        height: T.deckDot
                        radius: T.radiusSmall
                        color: T.textPrimary
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        visible: mark.modelData.kind === "gear"
                        width: T.deckGear
                        height: T.deckGear
                        source: "configure-symbolic"
                        fallback: "configure"
                        isMask: true
                        color: T.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deck.app.deck.goTo(mark.modelData.id)
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: T.motionFast
                        }
                    }
                }
            }
        }
    }
}
