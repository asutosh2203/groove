pragma ComponentBehavior: Bound

import QtQuick
import ".."

Rectangle {
    id: self

    required property var app

    radius: Math.min(width, height) / 2
    color: "#1b1b25"
    border.color: "#3d3d50"
    border.width: 1

    PlasmaLabel {
        anchors.centerIn: parent
        text: self.app.system.layoutShortName.toUpperCase()
        color: "#e2e2ed"
        font.pixelSize: Math.max(8, Math.min(11, parent.height * 0.42))
        font.weight: Font.Bold
    }
}
