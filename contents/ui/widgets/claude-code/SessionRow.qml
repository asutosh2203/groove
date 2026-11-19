pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.." as Island
import "../../controlcenter/Tokens.js" as T

// One session in the 2x1's list (D-60): state dot, project, " · message", lines changed, and a hairline of context fill.
// A waiting row adds the accent line. The item is the row's whole slot: its edges sit T.hoverInset inside the tile and the
// divider, so the highlight is the slot itself (D-61) and the content is centred in it with equal padding all round.
Item {
    id: row

    required property var info
    required property var base
    // Sliding up into a freed slot: the highlight stays on, brighter.
    property bool lifted: false
    readonly property bool waiting: row.info.state === "waiting"
    readonly property bool clickable: row.base.agents ? row.base.agents.raisable[row.info.id] === true : false
    readonly property color accent: T.agentAccents["claude-code"]
    readonly property var s: row.base.strings
    // Live rows say what they are doing now; a finished one says its last message.
    readonly property string tail: row.waiting ? "" : row.info.state === "done" ? row.info.message : row.s ? row.s.agentAction(row.info.action, row.info.target) : ""

    Island.HoverHighlight {
        containerRadius: T.radiusInner
        gap: T.hoverInset
        // A faint card at rest so the slot's padding reads as the row's own; hover and the lift brighten it.
        color: row.lifted || (row.clickable && hover.hovered) ? T.chip : T.rowHover
        shown: true
    }

    HoverHandler {
        id: hover

        enabled: row.clickable
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.clickable
        onClicked: row.base.runAction({ "type": "agent", "value": row.info.id })
    }

    Column {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        x: T.gap / 2 + T.widgetPadding - T.hoverInset
        width: row.width - content.x - (T.widgetPadding - T.hoverInset)
        spacing: T.deckSpacing

        RowLayout {
            id: line

            width: parent.width
            spacing: T.deckSpacing

            Rectangle {
                id: dot

                // A working row's dot breathes between white and the idle grey; nothing animates unless it works, shows and
                // motion is allowed (P9).
                property color pulse: T.textPrimary

                Layout.preferredWidth: T.liveBadgeRow
                Layout.preferredHeight: T.liveBadgeRow
                radius: T.liveBadgeRow / 2
                color: row.waiting ? row.accent : row.info.state === "working" ? dot.pulse : T.textTertiary

                SequentialAnimation {
                    running: row.info.state === "working" && row.visible && !row.base.reduceMotion
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            dot.pulse = T.textPrimary;
                    }

                    ColorAnimation {
                        target: dot
                        property: "pulse"
                        to: T.textTertiary
                        duration: T.motionPulse
                        easing.type: T.easingPulse
                    }

                    ColorAnimation {
                        target: dot
                        property: "pulse"
                        to: T.textPrimary
                        duration: T.motionPulse
                        easing.type: T.easingPulse
                    }
                }
            }

            Island.PlasmaLabel {
                Layout.maximumWidth: line.width / 2
                text: row.info.project
                color: T.textPrimary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Island.PlasmaLabel {
                Layout.fillWidth: true
                text: row.s ? row.s.claudeRowTail(row.tail) : ""
                color: T.textSecondary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Island.PlasmaLabel {
                text: row.s ? row.s.claudeLines(row.info.added, row.info.removed) : ""
                color: T.textSecondary
                font.pixelSize: T.fontCaption
                font.features: ({ "tnum": 1 })
                maximumLineCount: 1
            }
        }

        // Context fill, only once the window is nearly full (Claude.contextLevel): yellow above 80%, red above 90%.
        Rectangle {
            id: track

            width: parent.width
            height: T.widgetHairline
            radius: T.radiusSmall
            color: T.borderStrong
            visible: row.info.level !== "none"

            Rectangle {
                width: track.width * (row.info.context ?? 0) / 100
                height: parent.height
                radius: T.radiusSmall
                color: row.info.level === "critical" ? T.critical : T.warning
            }
        }

        Island.PlasmaLabel {
            width: parent.width
            visible: row.waiting
            text: row.s ? row.s.claudeNeedsOkLine(row.info.wants) : ""
            color: row.accent
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
