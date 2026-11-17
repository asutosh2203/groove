pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter"
import "../../controlcenter/Tokens.js" as T
import "../../logic/Catalogue.js" as Catalogue
import "../../logic/PageFit.js" as PageFit

// The catalogue sidebar (D-56): every widget the registry offers, with its supported spans. A widget that fits nowhere
// stays listed, greyed, with "won't fit". A click adds to the chosen free cell (else the first one that fits), a drag
// drops it onto the grid. Placements the page cannot take are listed first so they can be fixed.
Rectangle {
    id: catalogue

    required property var app
    required property var drag
    required property var host
    readonly property var ed: catalogue.app.editor
    readonly property var placements: catalogue.ed.preset ? catalogue.ed.preset.placements : []
    readonly property var spans: catalogue.placements.map(p => p.span)
    readonly property var unfit: PageFit.report(catalogue.ed.pageType, catalogue.spans).filter(r => !r.fits).map(r => r.index)
    readonly property var entries: Catalogue.entries(catalogue.ed.registry, catalogue.ed.pageType, catalogue.spans, catalogue.ed.cellIndex >= 0 ? catalogue.ed.cellIndex : null, Qt.locale().name)

    radius: T.radiusCard
    color: T.card
    border.width: 1
    border.color: T.border
    clip: true

    Flickable {
        anchors.fill: parent
        anchors.margins: T.gap
        contentWidth: width
        contentHeight: column.height
        interactive: contentHeight > height

        Column {
            id: column

            width: parent.width
            spacing: T.paddingCompact / 2

            PlasmaLabel {
                text: catalogue.app.strings.editWidgets
                color: T.textSecondary
                font.pixelSize: T.fontCaption
                height: T.editBadge
            }

            Repeater {
                model: catalogue.unfit.length

                delegate: Row {
                    id: unfitRow

                    required property int index
                    readonly property int placementIndex: catalogue.unfit[unfitRow.index]
                    readonly property string widgetId: catalogue.placements[unfitRow.placementIndex].widget

                    width: column.width
                    height: T.editEntry
                    spacing: T.gap

                    Rectangle {
                        width: parent.width - T.editBadge - T.gap
                        height: parent.height
                        radius: T.radiusInner
                        color: unfitHover.hovered ? T.rowHover : T.row
                        border.width: 1
                        border.color: T.borderStrong

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: T.gap
                            anchors.right: parent.right

                            PlasmaLabel {
                                width: parent.width
                                elide: Text.ElideRight
                                text: catalogue.ed.widgetName(unfitRow.widgetId)
                                color: T.textPrimary
                                font.pixelSize: T.fontBody
                            }

                            PlasmaLabel {
                                text: catalogue.app.strings.editDoesntFit
                                color: T.textSecondary
                                font.pixelSize: T.fontCaption
                            }
                        }

                        HoverHandler {
                            id: unfitHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: catalogue.ed.openForm(unfitRow.placementIndex)
                        }
                    }

                    RemoveBadge {
                        anchors.verticalCenter: parent.verticalCenter
                        tooltip: catalogue.app.strings.editRemoveWidget
                        onClicked: catalogue.ed.removePlacement(unfitRow.placementIndex)
                    }
                }
            }

            Repeater {
                model: catalogue.entries.length

                delegate: Rectangle {
                    id: entry

                    required property int index
                    readonly property var info: catalogue.entries[entry.index]

                    width: column.width
                    height: T.editEntry
                    radius: T.radiusInner
                    color: entry.info.fits && entryHover.hovered ? T.rowHover : T.row
                    opacity: entry.info.fits ? 1 : T.disabledOpacity

                    ThemeGlyph {
                        id: glyph

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: T.gap
                        width: T.iconTransport
                        height: T.iconTransport
                        names: entry.info.icon
                        color: T.textPrimary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: glyph.right
                        anchors.leftMargin: T.gap
                        anchors.right: parent.right
                        anchors.rightMargin: T.paddingCompact

                        PlasmaLabel {
                            width: parent.width
                            elide: Text.ElideRight
                            text: entry.info.name
                            color: T.textPrimary
                            font.pixelSize: T.fontBody
                        }

                        PlasmaLabel {
                            width: parent.width
                            elide: Text.ElideRight
                            text: entry.info.fits ? entry.info.spansLabel : entry.info.spansLabel + " · " + catalogue.app.strings.editWontFit
                            color: T.textSecondary
                            font.pixelSize: T.fontCaption
                        }
                    }

                    HoverHandler {
                        id: entryHover

                        enabled: entry.info.fits
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: entry.info.fits
                        onClicked: catalogue.ed.addWidget(entry.info.id, catalogue.ed.cellIndex >= 0 ? catalogue.ed.cellIndex : null)

                        DragHandler {
                            target: null
                            onActiveChanged: {
                                if (active)
                                    catalogue.host.dragBegin({ "kind": "add", "widgetId": entry.info.id }, T.deckCellW - 2 * T.deckPadding, T.deckCellH - 2 * T.deckPadding);
                                else
                                    catalogue.host.dragEnd();
                            }
                            onCentroidChanged: if (active) catalogue.host.dragMove(centroid.scenePosition)
                        }
                    }
                }
            }
        }
    }
}
