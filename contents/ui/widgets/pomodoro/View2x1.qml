pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T

// Pomodoro 2x1 (D-64): the 1x1 block, a hairline, then the round dots, what comes next and skip and reset.
PomodoroBase {
    id: view

    readonly property real dividerX: view.cellWidth + T.gap / 2
    // Ready: the left block already shows the focus length, so this says when the long break comes. Otherwise what is next.
    readonly property string sideText: !view.snap || !view.s ? "" : view.ready ? (view.snap.longAfter > 0 ? view.s.pomodoroLongAfter(view.snap.longAfter) : view.s.pomodoroNoLong) : view.s.pomodoroNextLong(view.snap.next, view.snap.longAfter)

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
        x: view.dividerX + T.widgetPadding
        y: T.widgetPadding
        width: view.width - x - T.widgetPadding
        height: view.height - 2 * T.widgetPadding

        Row {
            id: dots

            spacing: T.deckSpacing + 2

            Repeater {
                model: view.snap ? view.snap.dots : []

                delegate: Rectangle {
                    id: dot

                    required property int index
                    required property string modelData

                    width: T.pomodoroDot
                    height: T.pomodoroDot
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: dot.modelData === "upcoming" ? T.borderStrong : T.textPrimary

                    // The dot fills with light over its round's focus phase.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: T.pomodoroDotInset
                        radius: width / 2
                        color: T.textPrimary
                        opacity: view.snap?.dotFills[dot.index] ?? 0
                    }
                }
            }
        }

        Island.PlasmaLabel {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: dots.bottom
            anchors.topMargin: T.gap
            text: view.sideText
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Controls {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            base: view
        }
    }
}
