pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/FormModel.js" as FormModel
import "../../logic/PageFit.js" as PageFit
import "../../logic/Presets.js" as Presets
import "../" as Shell

// A widget's settings, opened in place (D-56): a live preview on the left, the fields generated from its manifest on the
// right (P11), the size control first. Widgets ship no settings screens.
Item {
    id: form

    required property var app
    // The deck's focus root, handed back when a field gives up focus.
    required property Item focusRoot
    readonly property var ed: form.app.editor
    readonly property var placement: form.ed.placement
    readonly property var manifest: form.placement ? form.ed.registry.byId[form.placement.widget] || null : null
    readonly property var model: form.manifest ? FormModel.build(form.manifest, form.placement, span => form.fitsSpan(span), Qt.locale().name) : null
    readonly property real previewWidth: T.editSidebar + 2 * T.editInset

    function fitsSpan(span) {
        const spans = form.ed.preset.placements.map(p => p.span);
        spans[form.ed.formIndex] = span;
        return PageFit.fits(form.ed.pageType, spans);
    }

    // The widget at this span's real size on this page, scaled down to the preview column when it is wider.
    readonly property var box: {
        const type = form.ed.pageType;
        const cell = ({ "small": [2, 1], "wide": [4, 1], "tall": [2, 2] })[type] || [2, 1];
        const boxes = Presets.boxes(type, cell[0] * T.deckCellW - 2 * T.deckPadding, cell[1] * T.deckCellH - 2 * T.deckPadding, T.gap, Presets.pack(type, form.placement ? [form.placement.span] : []));
        return boxes.length > 0 ? boxes[0] : { "w": T.deckCellW, "h": T.deckCellH };
    }
    readonly property real previewScale: Math.min(1, form.previewWidth / form.box.w)

    Item {
        id: preview

        width: form.previewWidth
        height: form.box.h * form.previewScale

        Shell.WidgetSlot {
            width: form.box.w
            height: form.box.h
            app: form.app
            placement: form.placement
            transformOrigin: Item.TopLeft
            scale: form.previewScale
        }

        PlasmaLabel {
            anchors.top: parent.bottom
            anchors.topMargin: T.gap
            text: form.app.strings.editPreview
            color: T.textSecondary
            font.pixelSize: T.fontCaption
        }
    }

    ColumnLayout {
        anchors.left: preview.right
        anchors.leftMargin: T.editGap
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0
        visible: form.model !== null

        // Size first: the spans that cannot fit this page stay visible, greyed.
        FormRow {
            label: form.app.strings.editSize

            Segmented {
                options: form.model ? form.model.size.options.map(o => ({ "value": o.value, "label": form.app.strings.spanName(o.value), "enabled": o.enabled })) : []
                value: form.model ? form.model.size.current : ""
                onPicked: value => form.ed.setSpan(value)
            }
        }

        Repeater {
            model: form.model ? form.model.fields.length : 0

            delegate: FormRow {
                id: fieldRow

                required property int index
                readonly property var field: form.model.fields[fieldRow.index]

                label: fieldRow.field.label

                Loader {
                    id: control

                    sourceComponent: fieldRow.field.control === "segmented" ? segmentedControl : fieldRow.field.control === "location" ? locationControl : null
                }

                Component {
                    id: segmentedControl

                    Segmented {
                        options: fieldRow.field.options
                        value: String(fieldRow.field.value)
                        onPicked: value => form.ed.setSetting(fieldRow.field.key, value)
                    }
                }

                Component {
                    id: locationControl

                    LocationField {
                        width: T.editSidebar + T.editInset * 2
                        app: form.app
                        focusRoot: form.focusRoot
                        value: fieldRow.field.value
                        onPicked: location => form.ed.setSetting(fieldRow.field.key, location)
                        onEditingChanged: fieldRow.z = editing ? 1 : 0
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: T.editRow

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: removeLabel.implicitWidth + 2 * T.padding + T.iconTransport + T.gap
                height: T.editChipH
                radius: T.radiusInner
                color: removeHover.hovered ? T.cardHover : T.raised

                Row {
                    anchors.centerIn: parent
                    spacing: T.gap

                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: T.iconTransport
                        height: T.iconTransport
                        source: "edit-delete-symbolic"
                        fallback: "edit-delete"
                        isMask: true
                        color: T.textCaption
                    }

                    PlasmaLabel {
                        id: removeLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: form.app.strings.editRemoveWidget
                        color: T.textCaption
                        font.pixelSize: T.fontBody
                    }
                }

                HoverHandler {
                    id: removeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: form.ed.removePlacement(form.ed.formIndex)
                }
            }
        }
    }

    // A labelled row with a hairline under it.
    component FormRow: Item {
        id: row

        property string label
        default property alias control: holder.data

        Layout.fillWidth: true
        Layout.preferredHeight: T.editRow

        PlasmaLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: T.textPrimary
            font.pixelSize: T.fontHeader
        }

        Item {
            id: holder

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: T.border
        }
    }
}
