pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClockFormat.js" as ClockFormat

// Pomodoro 4x1 (D-64), Wide page only: the 1x1 block, a hairline, the cycle length and when the long break comes, the whole
// cycle as a timeline sized by real lengths (done grey, current filling white, future dark), "N done", skip and reset.
PomodoroBase {
    id: view

    readonly property real dividerX: view.cellWidth + T.gap / 2
    readonly property var longAt: view.snap ? view.snap.longBreakAt : -1

    function atText(ms) {
        return ClockFormat.timeText(ms, -new Date(ms).getTimezoneOffset() * 60, "locale", view.use24Hour, view.locale.amText, view.locale.pmText);
    }

    LeftBlock {
        width: view.cellWidth
        height: view.height
        base: view
    }

    Rectangle {
        x: view.dividerX
        y: T.widgetPadding
        width: 1
        height: view.height - 2 * T.widgetPadding
        color: Qt.alpha(T.borderStrong, T.liveHairlineAlpha)
    }

    Item {
        id: right

        x: view.dividerX + T.widgetPadding
        y: T.widgetPadding
        width: view.width - x - T.widgetPadding
        height: view.height - 2 * T.widgetPadding

        Island.PlasmaLabel {
            id: cycle

            anchors.left: parent.left
            anchors.top: parent.top
            text: view.snap && view.s ? view.s.pomodoroCycle(Math.round(view.snap.cycleMs / 60000)) : ""
            color: T.textPrimary
            font.pixelSize: T.fontBody
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Island.PlasmaLabel {
            anchors.right: parent.right
            anchors.top: parent.top
            visible: view.longAt > 0
            text: view.longAt > 0 && view.s ? view.s.pomodoroLongAt(view.atText(view.longAt)) : ""
            color: T.textSecondary
            font.pixelSize: T.fontCaption
        }

        Row {
            id: timeline

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: T.pomodoroSegmentGap
            readonly property real total: view.snap ? view.snap.cycleMs : 1
            readonly property int count: view.snap ? view.snap.timeline.length : 0

            Repeater {
                model: view.snap ? view.snap.timeline : []

                delegate: Rectangle {
                    id: segment

                    required property var modelData

                    width: Math.max(2, (timeline.width - (timeline.count - 1) * timeline.spacing) * segment.modelData.ms / timeline.total)
                    height: T.pomodoroBar
                    radius: T.radiusSmall
                    color: segment.modelData.state === "done" ? T.textSecondary : T.track

                    Rectangle {
                        width: segment.modelData.state === "current" ? segment.width * segment.modelData.fill : 0
                        height: parent.height
                        radius: parent.radius
                        color: T.textPrimary
                    }
                }
            }
        }

        Island.PlasmaLabel {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: T.deckSpacing
            text: view.snap && view.s ? view.s.pomodoroDone(view.snap.done) : ""
            color: T.textSecondary
            font.pixelSize: T.fontCaption
        }

        Controls {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            base: view
        }
    }
}
