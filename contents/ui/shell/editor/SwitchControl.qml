pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T

// An on/off switch (D-56): neutral graphite, the knob and the track brighten when on (no colour, D-45).
Rectangle {
    id: sw

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: T.editChipH + T.gap
    implicitHeight: T.editBadge + T.deckDotSize
    radius: sw.height / 2
    color: sw.checked ? T.fillSoft : T.chip
    border.width: 1
    border.color: T.border
    Accessible.role: Accessible.CheckBox
    Accessible.checked: sw.checked

    Behavior on color {
        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    Rectangle {
        x: sw.checked ? sw.width - width - sw.border.width * 2 : sw.border.width * 2
        anchors.verticalCenter: parent.verticalCenter
        width: sw.height - sw.border.width * 4
        height: width
        radius: width / 2
        color: sw.checked ? T.iconOnFill : T.textCaption

        Behavior on x {
            NumberAnimation {
                duration: T.motionFast
                easing.type: T.easingStandard
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: sw.toggled(!sw.checked)
    }
}
