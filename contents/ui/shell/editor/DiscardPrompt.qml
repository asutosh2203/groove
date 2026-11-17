pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// "Discard your changes?" inside the island (D-56). Keep editing is the default: Esc and a click outside the card both
// keep editing.
Rectangle {
    id: prompt

    required property var app
    readonly property var strings: prompt.app.strings

    color: "#99000000"

    // Swallows clicks so nothing underneath reacts while the prompt is up.
    MouseArea {
        anchors.fill: parent
        onClicked: prompt.app.editor.promptOpen = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * T.editInset, T.controlWidth - 2 * T.editInset)
        height: column.implicitHeight + 2 * T.padding
        radius: T.radiusCard
        color: T.raised
        border.width: 1
        border.color: T.borderStrong

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.centerIn: parent
            width: parent.width - 2 * T.padding
            spacing: T.padding

            PlasmaLabel {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: prompt.strings.editDiscardTitle
                color: T.textPrimary
                font.pixelSize: T.fontTitle
                font.weight: Font.DemiBold
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: T.gap

                Repeater {
                    model: [{ "keep": true, "text": prompt.strings.editKeep }, { "keep": false, "text": prompt.strings.editDiscard }]

                    delegate: Rectangle {
                        id: choice

                        required property var modelData

                        width: choiceLabel.implicitWidth + 2 * T.padding
                        height: T.editChipH
                        radius: height / 2
                        color: choice.modelData.keep ? (choiceHover.hovered ? T.fill : T.fillSoft) : (choiceHover.hovered ? T.chip : T.row)
                        border.width: 1
                        border.color: T.border

                        PlasmaLabel {
                            id: choiceLabel

                            anchors.centerIn: parent
                            text: choice.modelData.text
                            color: choice.modelData.keep ? T.iconOnFill : T.textPrimary
                            font.pixelSize: T.fontBody
                        }

                        HoverHandler {
                            id: choiceHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: choice.modelData.keep ? prompt.app.editor.promptOpen = false : prompt.app.editor.discard()
                        }
                    }
                }
            }
        }
    }
}
