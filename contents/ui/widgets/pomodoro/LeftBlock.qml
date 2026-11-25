pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import ".." as Widgets
import "../claude-code" as Claude

// The 1x1 face of the Pomodoro widget, also the left block of the 2x1 and 4x1 (D-64): the phase as the label, a ring and
// mm:ss as the hero, the round as the detail, and play/pause top right. The ring is the Claude widget's. Focus and break
// differ by the label alone (D-45). Hovering the detail peeks what comes next.
Item {
    id: block

    required property var base
    property bool peeking: false
    readonly property var snap: block.base.snap
    readonly property bool peekShown: block.peeking && block.base.peek.length > 0

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered)
                dwell.restart();
            else {
                dwell.stop();
                block.peeking = false;
            }
        }
    }

    Timer {
        id: dwell

        interval: T.widgetPeekDwell
        onTriggered: block.peeking = true
    }

    Widgets.TileFace {
        id: tile

        anchors.fill: parent
        anchors.margins: T.widgetPadding
        label: block.base.label
        labelInset: T.widgetButton * (block.base.paused ? 2 : 1)
        hero: block.base.hero
        heroInset: T.widgetRing + T.gap
        heroSize: T.widgetHeroSizeSmall + 4
        heroShift: block.base.extra.length > 0 ? 8 : 0
        heroOpacity: block.base.ready ? T.disabledOpacity : 1
        detail: block.base.detail
        detailItem.opacity: block.peekShown ? 0 : 1

        Behavior on detailItem.opacity {
            enabled: !block.base.reduceMotion

            NumberAnimation {
                duration: T.motionHover
                easing.type: T.easingStandard
            }
        }

        Claude.Ring {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: block.base.extra.length > 0 ? -8 : 0
            width: T.widgetRing
            height: T.widgetRing
            pct: (block.snap?.progress ?? 0) * 100
            color: T.textPrimary
        }

        Island.PlasmaLabel {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: T.widgetPadding + 2
            visible: block.base.extra.length > 0
            text: block.base.extra
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Island.PlasmaLabel {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            opacity: block.peekShown ? 1 : 0
            text: block.base.peek
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1

            Behavior on opacity {
                enabled: !block.base.reduceMotion

                NumberAnimation {
                    duration: T.motionHover
                    easing.type: T.easingStandard
                }
            }
        }
    }

    // A paused timer can be reset right here, to the left of play.
    GlyphButton {
        objectName: "resetPaused"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: T.widgetPadding - 6
        anchors.rightMargin: T.widgetPadding - 6 + T.widgetButton
        visible: block.base.paused
        iconName: "view-refresh"
        tooltipText: block.base.s.pomodoroReset
        onClicked: block.base.hub.reset(block.base.pid)
    }

    GlyphButton {
        objectName: "play"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: T.widgetPadding - 6
        anchors.rightMargin: T.widgetPadding - 6
        iconName: block.base.running ? "media-playback-pause" : "media-playback-start"
        tooltipText: block.base.running ? block.base.s.pomodoroPause : block.base.s.pomodoroPlay
        onClicked: block.base.hub.toggle(block.base.pid)
    }
}
