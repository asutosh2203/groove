pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// The control of an enum field in the form (D-64): the current value and a "›". It opens the picker page; nothing drops down.
Rectangle {
    id: button

    property string text: ""

    signal activated

    implicitWidth: T.editFieldW
    implicitHeight: T.editChipH
    radius: height / 2
    color: hover.hovered ? T.chip : T.row
    border.width: 1
    border.color: button.activeFocus ? T.focusRing : T.border
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: button.text

    Keys.onReturnPressed: button.activated()
    Keys.onEnterPressed: button.activated()
    Keys.onSpacePressed: button.activated()

    PlasmaLabel {
        anchors.left: parent.left
        anchors.leftMargin: T.gap
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        text: button.text
        elide: Text.ElideRight
        color: T.textPrimary
        font.pixelSize: T.fontBody
    }

    PlasmaLabel {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: T.gap
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: T.textCaption
        font.pixelSize: T.fontHeader
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            button.forceActiveFocus();
            button.activated();
        }
    }
}
