import QtQuick

// A click-and-hover target dropped into a parent item (the media card's artwork and title block): a click asks the host to
// raise the player, hovering is reported for the card's own cue. A TapHandler, so the transport buttons beside it keep
// their own behaviour.
Item {
    id: area

    readonly property bool hovered: hover.hovered

    signal activated()

    anchors.fill: parent

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: area.activated()
    }
}
