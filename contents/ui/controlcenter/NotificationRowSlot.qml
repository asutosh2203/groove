import QtQuick
import ".."
import "Tokens.js" as T

// The single right-hand slot of a notification's top line. At rest it shows the age; on hover or keyboard
// focus the age cross-fades into the open glyph and the dismiss cross (same size, same muted colour, the
// cross brightens on its own hover). The slot keeps one fixed width, so nothing shifts while it fades.
Item {
    id: slot

    property string timeText: ""
    property bool revealed: false
    property bool clickable: false
    property bool dismissible: false
    property color timeColor: T.textTertiary
    property color iconColor: T.textCaption
    property real fontSize: T.fontCaption
    readonly property bool dismissFocused: dismissItem.activeFocus
    readonly property int iconCount: (clickable ? 1 : 0) + (dismissible ? 1 : 0)
    readonly property real iconSize: 14
    readonly property real iconsWidth: iconCount * iconSize + Math.max(0, iconCount - 1) * 8

    signal dismissRequested

    implicitWidth: Math.max(timeLabel.implicitWidth, iconsWidth)
    implicitHeight: Math.max(timeLabel.implicitHeight, iconSize)

    PlasmaLabel {
        id: timeLabel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: slot.timeText
        color: slot.timeColor
        font.pixelSize: slot.fontSize
        font.features: { "tnum": 1 }
        // Without any icon the age is always shown.
        opacity: slot.iconCount > 0 && slot.revealed ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        opacity: slot.revealed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }

        ThemeGlyph {
            visible: slot.clickable
            width: slot.iconSize
            height: slot.iconSize
            names: ["external-link-symbolic", "window-new-symbolic", "go-next-symbolic"]
            color: slot.iconColor
        }

        Item {
            id: dismissItem

            visible: slot.dismissible
            width: slot.iconSize
            height: slot.iconSize
            activeFocusOnTab: slot.dismissible
            Accessible.role: Accessible.Button
            Accessible.name: i18n("Dismiss")
            Accessible.onPressAction: slot.dismissRequested()
            Keys.onSpacePressed: slot.dismissRequested()
            Keys.onReturnPressed: slot.dismissRequested()
            Keys.onEnterPressed: slot.dismissRequested()

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 5
                color: "transparent"
                border.color: dismissItem.activeFocus ? T.focusRing : "transparent"
                border.width: 1
            }

            ThemeGlyph {
                anchors.fill: parent
                names: ["window-close-symbolic", "dialog-close", "window-close"]
                color: dismissArea.containsMouse ? T.textPrimary : slot.iconColor

                Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
            }

            // Larger than the glyph so it is easy to hit; it sits above the row's own click area.
            MouseArea {
                id: dismissArea

                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                enabled: slot.revealed
                cursorShape: Qt.PointingHandCursor
                onClicked: slot.dismissRequested()
            }
        }
    }
}
