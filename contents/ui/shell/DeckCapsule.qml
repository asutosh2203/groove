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

        // One delegate per page, kept as the pages' details change, so the colour, the dot and the glyph can animate.
        Repeater {
            model: capsule.items ? capsule.items.length : 0

            delegate: Item {
                id: entry

                required property int index

                readonly property var info: capsule.items && entry.index < capsule.items.length ? capsule.items[entry.index] : null
                readonly property bool current: entry.info !== null && capsule.app.deck.current === entry.info.id
                property color tone: current ? T.textPrimary : hover.hovered ? T.textSecondary : T.textTertiary

                width: T.deckCapsuleItem
                height: T.deckCapsuleItem
                Accessible.role: Accessible.Button
                Accessible.name: entry.info === null ? "" : entry.info.id === "live" ? capsule.app.strings.deckLive : entry.info.id === "control" ? capsule.app.strings.deckControlCenter : capsule.app.strings.deckPage(entry.info.id)

                Behavior on tone {
                    enabled: !capsule.reduceMotion

                    ColorAnimation {
                        duration: T.motionHover
                        easing.type: T.easingStandard
                    }
                }

                // A glyph that changes with the content (the Live item) cross-fades from the old one to the new.
                Item {
                    id: glyphPair

                    property bool showA: true
                    property var namesA: []
                    property var namesB: []

                    anchors.centerIn: parent
                    width: T.deckGlyph
                    height: T.deckGlyph
                    visible: entry.info !== null && entry.info.kind === "glyph"

                    function follow(next) {
                        if (next === null)
                            return ;
                        const shown = glyphPair.showA ? glyphPair.namesA : glyphPair.namesB;
                        if (JSON.stringify(next) === JSON.stringify(shown))
                            return ;
                        if (glyphPair.showA) {
                            glyphPair.namesB = next;
                            glyphPair.showA = false;
                        } else {
                            glyphPair.namesA = next;
                            glyphPair.showA = true;
                        }
                    }

                    Component.onCompleted: glyphPair.namesA = entry.info === null ? [] : entry.info.glyphs

                    Connections {
                        function onInfoChanged() {
                            glyphPair.follow(entry.info === null ? null : entry.info.glyphs);
                        }

                        target: entry
                    }

                    CC.ThemeGlyph {
                        anchors.fill: parent
                        names: glyphPair.namesA
                        color: entry.tone
                        opacity: glyphPair.showA ? 1 : 0

                        Behavior on opacity {
                            enabled: !capsule.reduceMotion

                            NumberAnimation {
                                duration: T.motionFade
                                easing.type: T.easingStandard
                            }
                        }
                    }

                    CC.ThemeGlyph {
                        anchors.fill: parent
                        names: glyphPair.namesB
                        color: entry.tone
                        opacity: glyphPair.showA ? 0 : 1

                        Behavior on opacity {
                            enabled: !capsule.reduceMotion

                            NumberAnimation {
                                duration: T.motionFade
                                easing.type: T.easingStandard
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: entry.info !== null && entry.info.kind === "dot"
                    width: entry.current ? T.deckDotActiveWidth : T.deckDotSize
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
                    onClicked: {
                        if (entry.info !== null)
                            capsule.app.deck.goTo(entry.info.id);
                    }
                }
            }
        }
    }
}
