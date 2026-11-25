pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/Stepper.js" as Stepper

// A number within min..max in steps: "− 25 min +" (D-56). Holding a button repeats and speeds up; the timer runs only
// while a button is held (P9).
Item {
    id: num

    property real value: 0
    property real min: 0
    property real max: 1
    property real step: 1
    // The value as shown, with its unit or zero label (FormModel.valueText).
    property string text: String(num.value)

    signal picked(real value)

    implicitWidth: row.implicitWidth
    implicitHeight: T.editChipH

    Row {
        id: row

        spacing: T.gap

        Repeater {
            model: [-1, 0, 1]

            delegate: Item {
                id: part

                required property int modelData
                readonly property bool atLimit: part.modelData < 0 ? num.value <= num.min : num.value >= num.max
                property int repeats: 0

                width: part.modelData === 0 ? Math.max(2 * T.editChipH, valueLabel.implicitWidth) : T.editChipH
                height: T.editChipH

                function stepOnce() {
                    if (part.atLimit)
                        return;
                    num.picked(Stepper.next(num.value, part.modelData, num.step, num.min, num.max));
                }

                Rectangle {
                    anchors.fill: parent
                    visible: part.modelData !== 0
                    radius: height / 2
                    color: partHover.hovered && !part.atLimit ? T.chip : T.row
                    border.width: 1
                    border.color: T.border
                    opacity: part.atLimit ? T.disabledOpacity : 1
                }

                PlasmaLabel {
                    id: valueLabel

                    anchors.centerIn: parent
                    text: part.modelData === 0 ? num.text : part.modelData < 0 ? "−" : "+"
                    color: T.textPrimary
                    font.pixelSize: T.fontHeader
                }

                Timer {
                    id: ticker

                    interval: T.stepHoldDelay
                    repeat: true
                    onTriggered: {
                        if (part.atLimit) {
                            ticker.stop();
                            return;
                        }
                        part.stepOnce();
                        part.repeats += 1;
                        ticker.interval = Stepper.interval(part.repeats, T.stepRepeatSlow, T.stepRepeatFast, T.stepRampRepeats);
                    }
                }

                HoverHandler {
                    id: partHover

                    enabled: part.modelData !== 0
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: press

                    enabled: part.modelData !== 0
                    onPressedChanged: {
                        if (press.pressed) {
                            part.repeats = 0;
                            part.stepOnce();
                            ticker.interval = T.stepHoldDelay;
                            ticker.restart();
                        } else {
                            ticker.stop();
                        }
                    }
                }
            }
        }
    }
}
