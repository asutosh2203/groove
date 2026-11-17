pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter/Tokens.js" as T

// Dev-only stand-in for a preset page (the deckDummyPages flag), so paging and morphs can be tested.
Rectangle {
    id: page

    property string label

    radius: T.radiusInner
    color: Qt.rgba(1, 1, 1, T.deckTileOpacity)

    PlasmaLabel {
        anchors.centerIn: parent
        text: page.label
        color: T.textSecondary
        font.pixelSize: T.fontCaption
    }
}
