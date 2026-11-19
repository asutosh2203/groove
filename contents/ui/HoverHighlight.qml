import QtQuick
import "controlcenter/Tokens.js" as T
import "logic/Concentric.js" as Concentric

// A hover highlight for a row inside a rounded container (D-61): its edges sit T.hoverInset inside the container and its
// corners are concentric with it. Place it first in the row; it covers the row's whole area, whatever the padding.
// The *Gap properties say how far the row's own edge is from the container's inner edge on that side.
Rectangle {
    id: highlight

    required property real containerRadius
    property bool shown: false
    property real gap: 0
    property real leftGap: highlight.gap
    property real rightGap: highlight.gap
    property real topGap: highlight.gap
    property real bottomGap: highlight.gap

    anchors.fill: parent
    anchors.leftMargin: Concentric.margin(highlight.leftGap, T.hoverInset)
    anchors.rightMargin: Concentric.margin(highlight.rightGap, T.hoverInset)
    anchors.topMargin: Concentric.margin(highlight.topGap, T.hoverInset)
    anchors.bottomMargin: Concentric.margin(highlight.bottomGap, T.hoverInset)
    radius: Concentric.radius(highlight.containerRadius, T.hoverInset)
    color: T.rowHover
    visible: highlight.shown
}
