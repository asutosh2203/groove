pragma ComponentBehavior: Bound

import QtQuick
import ".." as Island
import "../controlcenter/Tokens.js" as T

// The one structure every widget uses (D-55): a small grey label on top, a big hero value in the middle and a grey detail
// line at the bottom. Content added inside it (the weather glyph) sits on top.
Item {
    id: face

    property string label
    property string hero
    property string detail
    property real heroSize: T.widgetHeroSize
    // Room the label leaves on the right for something drawn over it (the weather glyph).
    property real labelInset: 0
    property alias detailItem: detailLabel
    default property alias extras: extraHost.data

    Island.PlasmaLabel {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: face.labelInset
        text: face.label
        color: T.textSecondary
        font.pixelSize: T.fontCaption
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Island.PlasmaLabel {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: face.hero
        color: T.textPrimary
        font.pixelSize: face.heroSize
        font.weight: T.widgetHeroWeight
        font.features: ({ "tnum": 1 })
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: T.fontTitle
        maximumLineCount: 1
    }

    Island.PlasmaLabel {
        id: detailLabel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        text: face.detail
        color: T.textSecondary
        font.pixelSize: T.fontCaption
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Item {
        id: extraHost

        anchors.fill: parent
    }
}
