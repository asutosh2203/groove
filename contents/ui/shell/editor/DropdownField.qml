pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// A dropdown for an enum with more than four options (D-56): the current choice as a pill, the options in a list under it.
// options: [{ value, label }].
Item {
    id: drop

    property var options: []
    property string value: ""
    property bool open: false
    readonly property string shown: {
        const match = drop.options.find(o => o.value === drop.value);
        return match ? match.label : drop.value;
    }

    signal picked(string value)

    implicitWidth: T.editSidebar + 2 * T.editInset
    implicitHeight: T.editChipH

    Rectangle {
        width: parent.width
        height: T.editChipH
        radius: height / 2
        color: head.hovered ? T.chip : T.row
        border.width: 1
        border.color: drop.open ? T.textTertiary : T.border

        PlasmaLabel {
            anchors.fill: parent
            anchors.leftMargin: T.gap
            anchors.rightMargin: T.gap
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: drop.shown + "  ▾"
            color: T.textPrimary
            font.pixelSize: T.fontBody
        }

        HoverHandler {
            id: head

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: drop.open = !drop.open
        }
    }

    Rectangle {
        visible: drop.open
        y: T.editChipH + T.deckDotSize
        z: 1
        width: parent.width
        height: Math.min(drop.options.length, 4) * T.editEntry
        radius: T.radiusInner
        color: T.raised
        border.width: 1
        border.color: T.borderStrong
        clip: true

        ListView {
            anchors.fill: parent
            interactive: contentHeight > height
            model: drop.options

            delegate: Rectangle {
                id: opt

                required property var modelData

                width: ListView.view.width
                height: T.editEntry
                color: "transparent"

                HoverHighlight {
                    containerRadius: T.radiusInner
                    shown: optHover.hovered
                }

                PlasmaLabel {
                    anchors.fill: parent
                    anchors.leftMargin: T.gap
                    verticalAlignment: Text.AlignVCenter
                    text: opt.modelData.label
                    color: opt.modelData.value === drop.value ? T.textPrimary : T.textCaption
                    font.pixelSize: T.fontBody
                }

                HoverHandler {
                    id: optHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        drop.open = false;
                        drop.picked(opt.modelData.value);
                    }
                }
            }
        }
    }
}
