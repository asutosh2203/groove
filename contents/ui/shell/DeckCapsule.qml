pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T

// The page-control capsule (D-51): a small pill floating just below the island, centred on it. One item per page in deck
// order: a glyph for Live and the Control Center, a dot per preset. A satellite of the deck, not a second island: it has the
// island's surface but no glow, and it is positioned and shown by PopupContent.
MouseArea {
    id: capsule

    required property var app
    required property bool control
    required property bool reduceMotion

    readonly property var items: capsule.app.deck.indicator

    implicitWidth: capsule.items ? capsule.items.length * T.deckCapsuleItem + 2 * T.deckCapsulePad : 0
    implicitHeight: T.deckCapsuleHeight
    width: implicitWidth
    height: implicitHeight
    // Clicks on the body do nothing, and are not outside clicks (the window's own handler would close the deck).
    acceptedButtons: Qt.LeftButton

    RoundShape {
        anchors.fill: parent
        radius: height / 2
        fillTop: capsule.control ? T.surfaceControlTop : "#121216"
        fillBottom: capsule.control ? T.surfaceControlBottom : "#060608"
        strokeColor: capsule.control ? "#25252b" : "#202027"
        rimOpacity: capsule.app.rimLight
    }

    Row {
        anchors.centerIn: parent

        Repeater {
            model: capsule.items

            delegate: Item {
                id: entry

                required property var modelData

                property color tone: modelData.current ? T.textPrimary : hover.hovered ? T.textSecondary : T.textTertiary

                width: T.deckCapsuleItem
                height: T.deckCapsuleItem
                Accessible.role: Accessible.Button
                Accessible.name: modelData.id === "live" ? capsule.app.strings.deckLive : modelData.id === "control" ? capsule.app.strings.deckControlCenter : capsule.app.strings.deckPage(modelData.id)

                Behavior on tone {
                    enabled: !capsule.reduceMotion

                    ColorAnimation {
                        duration: T.motionHover
                        easing.type: T.easingStandard
                    }
                }

                CC.ThemeGlyph {
                    anchors.centerIn: parent
                    width: T.deckGlyph
                    height: T.deckGlyph
                    visible: entry.modelData.kind === "glyph"
                    names: entry.modelData.glyphs
                    color: entry.tone
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: entry.modelData.kind === "dot"
                    width: entry.modelData.current ? T.deckDotActiveWidth : T.deckDotSize
                    height: T.deckDotSize
                    radius: height / 2
                    color: entry.tone

                    Behavior on width {
                        enabled: !capsule.reduceMotion

                        NumberAnimation {
                            duration: T.motionFast
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
                    onClicked: capsule.app.deck.goTo(entry.modelData.id)
                }
            }
        }
    }
}
