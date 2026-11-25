pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.."
import "../../controlcenter/Tokens.js" as T

// The edit mode's top bar (D-56): the page-type control (or "‹ widget" in the form, or the Control Center title) on the
// left, a note, and the ✕ and ✓ buttons the Control Center editor always had, now for the whole session.
RowLayout {
    id: bar

    required property var app
    readonly property var ed: bar.app.editor
    readonly property var strings: bar.app.strings
    readonly property bool inForm: bar.ed.view === "preset" && bar.ed.pane === "form"
    // The picker page of an enum field: "‹ <field>" in place of "‹ <widget>", and no ✕ ✓ until it closes (D-64).
    readonly property bool inPicker: bar.inForm && bar.ed.pickerKey.length > 0
    readonly property string note: bar.ed.hint.length > 0 ? bar.strings.editHint(bar.ed.hint) : bar.ed.locked ? bar.strings.editDevPresets : bar.ed.restoredNote ? bar.strings.editRestored : ""

    spacing: T.gap

    Segmented {
        visible: bar.ed.view === "preset" && !bar.inForm
        options: ["small", "wide", "tall"].map(type => ({ "value": type, "label": bar.strings.pageTypeName(type) }))
        value: bar.ed.pageType
        onPicked: value => bar.ed.setPage(value)
    }

    // "‹ Weather": back to the grid.
    Item {
        visible: bar.inForm
        implicitWidth: backRow.implicitWidth
        implicitHeight: T.editChipH

        Row {
            id: backRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: T.paddingCompact / 2

            // A plain chevron: IslandButton's legacy glyphs read "previous" as a media skip.
            // Both labels are as tall as the bar's buttons and centred in it, so the chevron, the name and the ✕ ✓ share a line.
            PlasmaLabel {
                height: T.editChipH
                verticalAlignment: Text.AlignVCenter
                text: "‹"
                color: backHover.hovered ? T.textPrimary : T.textCaption
                font.pixelSize: T.fontTitle + T.fontHeader
                // The big glyph sits low in its line box; this lifts it to the name's line.
                bottomPadding: T.fontHeader / 2

                HoverHandler {
                    id: backHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: bar.inPicker ? bar.ed.closePicker() : bar.ed.backToGrid()
                }
            }

            PlasmaLabel {
                height: T.editChipH
                verticalAlignment: Text.AlignVCenter
                text: bar.inPicker ? bar.ed.pickerLabel : bar.ed.placement ? bar.ed.widgetName(bar.ed.placement.widget) : ""
                color: T.textPrimary
                font.pixelSize: T.fontHeader
                font.weight: Font.DemiBold
            }
        }
    }

    PlasmaLabel {
        visible: bar.ed.view === "gear"
        text: bar.strings.editGear
        color: T.textPrimary
        font.pixelSize: T.fontHeader
        font.weight: Font.DemiBold
    }

    PlasmaLabel {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: bar.note
        color: bar.ed.hint.length > 0 ? T.textPrimary : T.textSecondary
        font.pixelSize: T.fontCaption
    }

    IslandButton {
        visible: bar.ed.view === "gear"
        iconName: "restore-defaults"
        compact: true
        restColor: T.raised
        hoverColor: T.chip
        pressedColor: T.cardPressed
        outlineColor: T.border
        focusColor: T.focusRing
        tooltipText: bar.strings.editReset
        onClicked: bar.app.layoutService.resetLayout()
    }

    IslandButton {
        visible: !bar.inPicker
        iconName: "dialog-cancel"
        compact: true
        restColor: T.raised
        hoverColor: T.chip
        pressedColor: T.cardPressed
        outlineColor: T.border
        focusColor: T.focusRing
        emphasized: bar.ed.dirty
        tooltipText: bar.strings.editCancel
        onClicked: bar.ed.requestCancel()
    }

    IslandButton {
        visible: !bar.inPicker
        iconName: "dialog-ok-apply"
        compact: true
        restColor: T.raised
        hoverColor: T.chip
        pressedColor: T.cardPressed
        outlineColor: T.border
        focusColor: T.focusRing
        emphasized: bar.ed.dirty
        tooltipText: bar.strings.editDone
        onClicked: bar.ed.done()
    }
}
