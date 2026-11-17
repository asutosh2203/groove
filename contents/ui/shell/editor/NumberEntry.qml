pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import "../.."
import "../../controlcenter/Tokens.js" as T

// A number within min..max in steps: a stepper (− value +) when there are few steps, else a slider with its value (D-56).
Item {
    id: num

    property bool slider: false
    property real value: 0
    property real min: 0
    property real max: 1
    property real step: 1

    signal picked(real value)

    function clamp(v) {
        return Math.min(num.max, Math.max(num.min, v));
    }

    implicitWidth: num.slider ? T.editSidebar + T.editInset : stepper.implicitWidth
    implicitHeight: T.editChipH

    Row {
        id: stepper

        visible: !num.slider
        spacing: T.gap

        Repeater {
            model: [-1, 0, 1]

            delegate: Item {
                id: part

                required property int modelData

                width: part.modelData === 0 ? valueLabel.implicitWidth : T.editChipH
                height: T.editChipH

                Rectangle {
                    anchors.fill: parent
                    visible: part.modelData !== 0
                    radius: height / 2
                    color: partHover.hovered ? T.chip : T.row
                    border.width: 1
                    border.color: T.border
                    opacity: (part.modelData < 0 ? num.value > num.min : num.value < num.max) ? 1 : T.disabledOpacity
                }

                PlasmaLabel {
                    id: valueLabel

                    anchors.centerIn: parent
                    text: part.modelData === 0 ? String(num.value) : part.modelData < 0 ? "−" : "+"
                    color: T.textPrimary
                    font.pixelSize: T.fontHeader
                }

                HoverHandler {
                    id: partHover

                    enabled: part.modelData !== 0
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: part.modelData !== 0
                    onTapped: num.picked(num.clamp(num.value + part.modelData * num.step))
                }
            }
        }
    }

    Row {
        visible: num.slider
        spacing: T.gap

        QQC2.Slider {
            width: T.editSidebar - T.editInset
            from: num.min
            to: num.max
            stepSize: num.step
            value: num.value
            onMoved: num.picked(value)
        }

        PlasmaLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: String(num.value)
            color: T.textPrimary
            font.pixelSize: T.fontBody
        }
    }
}
