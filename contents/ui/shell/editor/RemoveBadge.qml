pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// The small "−" on a widget or a chip that removes it (D-56). A MouseArea, so the click stays here.
Rectangle {
    id: badge

    property string tooltip: ""

    signal clicked

    width: T.editBadge
    height: T.editBadge
    radius: width / 2
    color: area.containsMouse ? T.chip : T.raised
    border.width: 1
    border.color: T.borderStrong
    Accessible.role: Accessible.Button
    Accessible.name: badge.tooltip

    PlasmaLabel {
        anchors.centerIn: parent
        text: "−"
        color: T.textPrimary
        font.pixelSize: T.fontHeader
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.clicked()
    }
}
