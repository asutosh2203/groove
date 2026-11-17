pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// A segmented control: a pill of options with the chosen one raised (D-56). options: [{ value, label, enabled? }]; a
// disabled option stays visible, greyed, and does not react.
Rectangle {
    id: seg

    property var options: []
    property string value: ""

    signal picked(string value)

    implicitWidth: row.implicitWidth + seg.border.width * 4
    implicitHeight: T.editChipH
    radius: seg.height / 2
    color: T.row
    border.width: 1
    border.color: T.border

    Row {
        id: row

        anchors.centerIn: parent

        Repeater {
            model: seg.options

            delegate: Rectangle {
                id: item

                required property var modelData
                readonly property bool current: item.modelData.value === seg.value
                readonly property bool usable: item.modelData.enabled !== false

                width: label.implicitWidth + 2 * T.padding
                height: seg.height - seg.border.width * 4
                radius: item.height / 2
                color: item.current ? T.chip : item.usable && hover.hovered ? T.rowHover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: T.motionHover
                        easing.type: T.easingStandard
                    }
                }

                PlasmaLabel {
                    id: label

                    anchors.centerIn: parent
                    text: item.modelData.label
                    color: !item.usable ? T.textTertiary : item.current ? T.textPrimary : T.textCaption
                    font.pixelSize: T.fontBody
                }

                // Passive hover, so nothing above it can steal the highlight (the HoverHandler lesson).
                HoverHandler {
                    id: hover

                    enabled: item.usable
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: item.usable
                    onTapped: seg.picked(item.modelData.value)
                }
            }
        }
    }
}
