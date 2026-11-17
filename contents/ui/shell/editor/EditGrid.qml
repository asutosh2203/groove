pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/PageFit.js" as PageFit
import "../../logic/Presets.js" as Presets
import "../" as Shell

// The grid view (D-56): the preset page at real size inside a dashed outline. A click on a widget opens its form.
Item {
    id: grid

    required property var app
    readonly property var ed: grid.app.editor
    readonly property var cell: ({ "small": [2, 1], "wide": [4, 1], "tall": [2, 2] })[grid.ed.pageType] || [2, 1]
    readonly property real pageW: grid.cell[0] * T.deckCellW - 2 * T.deckPadding
    readonly property real pageH: grid.cell[1] * T.deckCellH - 2 * T.deckPadding
    readonly property var placements: grid.ed.preset ? grid.ed.preset.placements : []
    // What fits shows; the rest is for the "Doesn't fit" list (a stored preset can hold more than its page takes).
    readonly property var report: PageFit.report(grid.ed.pageType, grid.placements.map(p => p.span))
    readonly property var shownIndexes: grid.report.filter(r => r.fits).map(r => r.index)
    readonly property var boxes: Presets.boxes(grid.ed.pageType, grid.pageW, grid.pageH, T.gap, Presets.pack(grid.ed.pageType, grid.shownIndexes.map(i => grid.placements[i].span)))

    Shape {
        x: 0
        y: 0
        width: grid.pageW + 2 * T.editOutlinePad
        height: grid.pageH + 2 * T.editOutlinePad

        ShapePath {
            strokeColor: T.borderStrong
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]

            PathRectangle {
                x: 0
                y: 0
                width: grid.pageW + 2 * T.editOutlinePad
                height: grid.pageH + 2 * T.editOutlinePad
                radius: T.radiusInner
            }
        }
    }

    Item {
        x: T.editOutlinePad
        y: T.editOutlinePad
        width: grid.pageW
        height: grid.pageH

        Repeater {
            // A count, not the array: a Repeater over a JS array rebuilds every delegate on any change.
            model: grid.shownIndexes.length

            delegate: Item {
                id: cellItem

                required property int index
                readonly property int placementIndex: grid.shownIndexes[cellItem.index]
                // The boxes follow a moment after the list when the page changes.
                readonly property var box: grid.boxes[cellItem.index] || ({ "x": 0, "y": 0, "w": 0, "h": 0 })

                x: cellItem.box.x
                y: cellItem.box.y
                width: cellItem.box.w
                height: cellItem.box.h

                Shell.WidgetSlot {
                    anchors.fill: parent
                    app: grid.app
                    placement: grid.placements[cellItem.placementIndex]
                }

                // Above the slot, so a widget's own click (calendar, forecast) never fires in the editor.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: grid.ed.openForm(cellItem.placementIndex)
                }
            }
        }
    }

    PlasmaLabel {
        anchors.top: parent.top
        anchors.topMargin: grid.pageH + 2 * T.editOutlinePad + T.gap
        text: grid.app.strings.editGridHint
        color: T.textSecondary
        font.pixelSize: T.fontCaption
    }
}
