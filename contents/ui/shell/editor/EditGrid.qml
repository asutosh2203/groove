pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/PageFit.js" as PageFit
import "../../logic/Presets.js" as Presets
import "../" as Shell

// The grid view (D-56): the preset page at real size inside a dashed outline. A click on a widget opens its form, "−"
// removes it, a drag reorders, and a free cell offers "Add widget" for the catalogue beside it.
Item {
    id: grid

    required property var app
    // The drag in progress (EditPage): active, pos in the edit page, payload.
    required property var drag
    // The edit page, whose coordinates the drag reports in.
    required property var host
    readonly property var ed: grid.app.editor
    readonly property var cell: ({ "small": [2, 1], "wide": [4, 1], "tall": [2, 2] })[grid.ed.pageType] || [2, 1]
    readonly property real pageW: grid.cell[0] * T.deckCellW - 2 * T.deckPadding
    readonly property real pageH: grid.cell[1] * T.deckCellH - 2 * T.deckPadding
    readonly property real cellW: (grid.pageW - T.gap * (grid.cell[0] - 1)) / grid.cell[0]
    readonly property real cellH: (grid.pageH - T.gap * (grid.cell[1] - 1)) / grid.cell[1]
    readonly property var placements: grid.ed.preset ? grid.ed.preset.placements : []
    readonly property var spans: grid.placements.map(p => p.span)
    readonly property var report: PageFit.report(grid.ed.pageType, grid.spans)
    // What fits shows; the rest is listed in the catalogue as "Doesn't fit" (a stored preset can hold more than its page).
    readonly property var shownIndexes: grid.report.filter(r => r.fits).map(r => r.index)
    readonly property bool allFit: grid.shownIndexes.length === grid.spans.length
    readonly property var boxes: Presets.boxes(grid.ed.pageType, grid.pageW, grid.pageH, T.gap, Presets.pack(grid.ed.pageType, grid.shownIndexes.map(i => grid.placements[i].span)))
    readonly property var freeCells: PageFit.emptyCells(grid.ed.pageType, grid.shownIndexes.map(i => grid.spans[i]))
    // While dragging: what the pointer is over.
    readonly property var target: grid.drag.active && grid.allFit ? PageFit.dropTarget(grid.ed.pageType, grid.spans, grid.pageW, grid.pageH, T.gap, content.mapFromItem(grid.host, grid.drag.pos.x, grid.drag.pos.y)) : ({ "kind": "none", "index": -1 })

    // The drag ended at `pos` (edit page coordinates).
    function drop(pos, payload) {
        if (!grid.allFit)
            return ;
        const t = PageFit.dropTarget(grid.ed.pageType, grid.spans, grid.pageW, grid.pageH, T.gap, content.mapFromItem(grid.host, pos.x, pos.y));
        if (t.kind === "none")
            return ;
        if (payload.kind === "move")
            grid.ed.moveWidget(payload.index, PageFit.moveIndex(payload.index, t));
        else
            grid.ed.addWidget(payload.widgetId, t.index);
    }

    DashedBox {
        width: grid.pageW + 2 * T.editOutlinePad
        height: grid.pageH + 2 * T.editOutlinePad
    }

    Item {
        id: content

        x: T.editOutlinePad
        y: T.editOutlinePad
        width: grid.pageW
        height: grid.pageH

        // The free cells.
        Repeater {
            model: grid.freeCells.length

            delegate: Item {
                id: freeCell

                required property int index
                readonly property var info: grid.freeCells[freeCell.index]
                readonly property bool chosen: grid.ed.cellIndex === freeCell.info.index
                readonly property bool dropHere: grid.target.kind === "cell" && grid.target.col === freeCell.info.col && grid.target.row === freeCell.info.row

                x: freeCell.info.col * (grid.cellW + T.gap)
                y: freeCell.info.row * (grid.cellH + T.gap)
                width: grid.cellW
                height: grid.cellH

                DashedBox {
                    anchors.fill: parent
                    stroke: freeCell.chosen || freeCell.dropHere ? T.textCaption : T.borderStrong
                }

                PlasmaLabel {
                    anchors.centerIn: parent
                    text: "+  " + grid.app.strings.editAddWidget
                    color: freeCell.chosen || hover.hovered ? T.textPrimary : T.textSecondary
                    font.pixelSize: T.fontBody
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: grid.ed.pickCell(freeCell.info.index)
                }
            }
        }

        Repeater {
            // A count, not the array: a Repeater over a JS array rebuilds every delegate on any change.
            model: grid.shownIndexes.length

            delegate: Item {
                id: cellItem

                required property int index
                readonly property int placementIndex: grid.shownIndexes[cellItem.index]
                // The boxes follow a moment after the list when the page changes.
                readonly property var box: grid.boxes[cellItem.index] || ({ "x": 0, "y": 0, "w": 0, "h": 0 })
                readonly property bool dragged: grid.drag.active && grid.drag.payload.kind === "move" && grid.drag.payload.index === cellItem.placementIndex

                x: cellItem.box.x
                y: cellItem.box.y
                width: cellItem.box.w
                height: cellItem.box.h
                opacity: cellItem.dragged ? T.disabledOpacity : 1

                Shell.WidgetSlot {
                    anchors.fill: parent
                    app: grid.app
                    placement: grid.placements[cellItem.placementIndex]
                }

                // Above the slot, so a widget's own click (calendar, forecast) never fires in the editor. A click opens
                // the form; a drag past the threshold reorders (the DragHandler takes the grab and the click ends).
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: grid.ed.openForm(cellItem.placementIndex)

                    DragHandler {
                        target: null
                        enabled: grid.allFit
                        onActiveChanged: {
                            if (active)
                                grid.host.dragBegin({ "kind": "move", "index": cellItem.placementIndex }, cellItem.width, cellItem.height);
                            else
                                grid.host.dragEnd();
                        }
                        onCentroidChanged: if (active) grid.host.dragMove(centroid.scenePosition)
                    }
                }

                RemoveBadge {
                    x: -T.editBadge / 3
                    y: -T.editBadge / 3
                    tooltip: grid.app.strings.editRemoveWidget
                    onClicked: grid.ed.removePlacement(cellItem.placementIndex)
                }
            }
        }

        // Where a drop would land.
        Rectangle {
            readonly property var free: grid.target.kind === "cell" ? grid.freeCells.find(c => c.col === grid.target.col && c.row === grid.target.row) : null
            readonly property var tile: grid.target.kind === "tile" ? grid.boxes[grid.target.index] : null

            visible: grid.target.kind !== "none" && (free || tile)
            x: tile ? tile.x : free ? free.col * (grid.cellW + T.gap) : 0
            y: tile ? tile.y : free ? free.row * (grid.cellH + T.gap) : 0
            width: tile ? tile.w : grid.cellW
            height: tile ? tile.h : grid.cellH
            radius: T.radiusInner
            color: "transparent"
            border.width: 2
            border.color: T.textCaption
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
