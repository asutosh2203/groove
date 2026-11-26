pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/FormModel.js" as FormModel
import "../../logic/PageFit.js" as PageFit
import "../" as Shell

// A widget's settings, opened in place (D-56): the live preview and the fields generated from its manifest (P11), laid out
// by FormLayout (preview left for narrow widgets, on top at real size for wide ones), the size control first. Widgets
// ship no settings screens.
Item {
    id: form

    required property var app
    // The deck's focus root, handed back when a field gives up focus.
    required property Item focusRoot
    readonly property var ed: form.app.editor
    readonly property var placement: form.ed.placement
    readonly property var manifest: form.placement ? form.ed.registry.byId[form.placement.widget] || null : null
    readonly property var model: form.manifest ? FormModel.build(form.manifest, form.placement, span => form.fitsSpan(span), Qt.locale().name, { "sensors": form.app.sysmon.available }) : null
    readonly property var plan: form.app.formPlan

    function fitsSpan(span) {
        const spans = form.ed.preset.placements.map(p => p.span);
        spans[form.ed.formIndex] = span;
        return PageFit.fits(form.ed.pageType, spans);
    }

    // The form and the picker page of an enum field slide side by side (D-64): opening a picker moves the form out to the left.
    readonly property bool picking: form.ed.pickerKey.length > 0
    readonly property var pickerModel: form.picking && form.model ? form.model.fields.find(f => f.key === form.ed.pickerKey) || null : null
    // The last picker shown, kept while the page slides away.
    property var lastPicker: null

    // The picker page is gone, so the deck takes the keyboard back (Esc steps out of the form).
    onPickingChanged: {
        if (!form.picking)
            form.focusRoot.forceActiveFocus();
    }

    onPickerModelChanged: {
        if (form.pickerModel)
            form.lastPicker = form.pickerModel;
    }

    clip: true

    Item {
        id: body

        x: form.picking ? -form.width : 0
        width: form.width
        height: form.height

        Behavior on x {
            enabled: !form.app.reduceMotion

            NumberAnimation {
                duration: T.motionPage
                easing.type: T.easingStandard
            }
        }

        // The widget at its real size, centred on a full-width stage.
        Rectangle {
            id: stage

            width: form.width
            height: form.plan ? form.plan.stageH : 0
            radius: T.radiusInner
            color: T.card
            border.width: 1
            border.color: T.border

            Shell.WidgetSlot {
                x: form.plan ? (stage.width - form.plan.box.w) / 2 : 0
                y: form.plan ? (stage.height - form.plan.box.h) / 2 : 0
                width: form.plan ? form.plan.box.w : 0
                height: form.plan ? form.plan.box.h : 0
                app: form.app
                placement: form.placement
            }
        }

        // The size control, then the fields in two columns.
        Column {
            id: fields

            readonly property real colGap: 2 * T.editInset

            y: stage.height + T.editGap
            width: form.width
            spacing: 0
            visible: form.model !== null && form.plan !== null

            FormRow {
                width: fields.width
                label: form.app.strings.editSize

                Loader {
                    sourceComponent: form.model && form.model.size.options.length > 1 ? sizeSegmented : sizeOnly
                }

                Component {
                    id: sizeOnly

                    PlasmaLabel {
                        text: form.app.strings.spanOnly(form.model.size.current)
                        color: T.textSecondary
                        font.pixelSize: T.fontHeader
                    }
                }

                Component {
                    id: sizeSegmented

                Segmented {
                    options: form.model ? form.model.size.options.map(o => ({ "value": o.value, "label": form.app.strings.spanName(o.value), "enabled": o.enabled })) : []
                    value: form.model ? form.model.size.current : ""
                    onPicked: value => form.ed.setSpan(value)
                }
                }
            }

            Row {
                spacing: fields.colGap

                Repeater {
                    model: form.plan ? form.plan.cols : []

                    delegate: Column {
                        id: fieldColumn

                        required property var modelData

                        width: form.plan ? (fields.width - (form.plan.cols.length - 1) * fields.colGap) / form.plan.cols.length : 0

                        Repeater {
                            model: fieldColumn.modelData

                            delegate: FormRow {
                                id: fieldRow

                                required property int modelData
                                // The model and the layout plan update one after the other, so for a moment the plan can name a field
                                // the new widget lacks; a blank field draws nothing until the plan catches up.
                                readonly property var noField: ({ "control": "", "label": "", "key": "", "shown": "", "value": "", "options": [] })
                                readonly property var field: (form.model ? form.model.fields[fieldRow.modelData] : undefined) || fieldRow.noField

                                width: fieldColumn.width
                                // An open dropdown or search must draw over the other column too.
                                onZChanged: fieldColumn.z = fieldRow.z
                                kind: fieldRow.field.control
                                label: fieldRow.field.control === "note" ? "" : fieldRow.field.label

                                Loader {
                                    id: control

                                    sourceComponent: ({ "picker": pickerControl, "location": locationControl, "switch": switchControl, "text": textControl, "stepper": numberControl, "timezone": timezoneControl, "note": noteControl })[fieldRow.field.control] || null
                                }

                                // A computed read-only line (D-64): it spans the whole row, so the row's own label is empty.
                                Component {
                                    id: noteControl

                                    PlasmaLabel {
                                        width: fieldRow.width
                                        text: form.app.strings.widgetNote(fieldRow.field.note)
                                        color: T.textSecondary
                                        font.pixelSize: T.fontCaption
                                        elide: Text.ElideRight
                                    }
                                }

                                Component {
                                    id: pickerControl

                                    PickerButton {
                                        text: fieldRow.field.shown
                                        onActivated: form.ed.openPicker(fieldRow.field.key)
                                    }
                                }

                                Component {
                                    id: switchControl

                                    SwitchControl {
                                        checked: fieldRow.field.value === true
                                        onToggled: checked => form.ed.setSetting(fieldRow.field.key, checked)
                                    }
                                }

                                Component {
                                    id: textControl

                                    TextEntry {
                                        width: T.editFieldW
                                        app: form.app
                                        focusRoot: form.focusRoot
                                        value: String(fieldRow.field.value)
                                        onCommitted: text => form.ed.setSetting(fieldRow.field.key, text)
                                    }
                                }

                                Component {
                                    id: numberControl

                                    NumberEntry {
                                        value: Number(fieldRow.field.value)
                                        text: FormModel.valueText(fieldRow.field, fieldRow.field.value)
                                        min: fieldRow.field.min
                                        max: fieldRow.field.max
                                        step: fieldRow.field.step
                                        onPicked: value => form.ed.setSetting(fieldRow.field.key, value)
                                    }
                                }

                                Component {
                                    id: locationControl

                                    LocationField {
                                        width: T.editFieldW
                                        app: form.app
                                        focusRoot: form.focusRoot
                                        value: fieldRow.field.value
                                        onPicked: location => form.ed.setSetting(fieldRow.field.key, location)
                                        onEditingChanged: fieldRow.z = editing ? 1 : 0
                                    }
                                }

                                Component {
                                    id: timezoneControl

                                    TimezoneField {
                                        width: T.editFieldW
                                        app: form.app
                                        focusRoot: form.focusRoot
                                        value: String(fieldRow.field.value)
                                        onPicked: zone => form.ed.setSetting(fieldRow.field.key, zone)
                                        onEditingChanged: fieldRow.z = editing ? 1 : 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom left, under the fields.
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            visible: form.model !== null
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

    Item {
        id: pickerHost

        x: form.picking ? 0 : form.width
        width: form.width
        height: form.height

        Behavior on x {
            enabled: !form.app.reduceMotion

            NumberAnimation {
                duration: T.motionPage
                easing.type: T.easingStandard
            }
        }

        Loader {
            anchors.fill: parent
            active: form.lastPicker !== null && (form.picking || pickerHost.x < form.width)

            sourceComponent: PickerPage {
                options: form.lastPicker.options
                value: String(form.lastPicker.value)
                missingText: form.app.strings.editOptionMissing
                onPicked: value => form.ed.pick(value)
            }
        }
    }

    // A labelled row with a hairline under it.
    component FormRow: Item {
        id: row

        property string label
        property string kind
        default property alias control: holder.data

        height: row.kind === "note" ? T.editNote : T.editRow

        PlasmaLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, row.width - holder.width - T.gap)
            text: row.label
            elide: Text.ElideRight
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
