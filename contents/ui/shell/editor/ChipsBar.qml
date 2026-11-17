pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter"
import "../../controlcenter/Tokens.js" as T
import "../../logic/Silhouette.js" as Silhouette

// The chips bar at the bottom of the edit mode (D-56): one chip per preset, a tiny silhouette of its layout (no names),
// then the gear chip for the Control Center tiles and "+ New". It is the navigator: the capsule is hidden while editing.
// On hover a chip shows an eye (in or out of the cycle) and a "−" (delete, staged until Done); a drag reorders.
Item {
    id: bar

    required property var app
    readonly property var ed: bar.app.editor
    readonly property real step: T.editChipW + T.gap

    height: T.editChipH

    Repeater {
        model: bar.ed.presetCount

        delegate: Rectangle {
            id: chip

            required property int index
            readonly property var preset: bar.ed.draft.presets[chip.index]
            readonly property bool current: bar.ed.view === "preset" && bar.ed.presetId === chip.preset.id
            readonly property bool near: chipHover.hovered || eyeArea.containsMouse || removeBadge.hovered
            readonly property var drawing: Silhouette.rects(chip.preset.page, chip.preset.placements.map(p => p.span), { "w": T.editChipW - 2 * T.paddingCompact, "h": T.editChipH - 2 * T.paddingCompact }, { "w": T.deckCellW, "h": T.deckCellH }, T.editSilhouetteGap)
            // While dragged the chip follows the pointer; on release it lands on the nearest slot.
            property real dragDx: 0

            x: chip.index * bar.step + chip.dragDx
            z: chip.dragDx !== 0 ? 1 : 0
            width: T.editChipW
            height: T.editChipH
            radius: T.radiusInner / 2
            color: chipHover.hovered ? T.chip : T.raised
            border.width: chip.current ? 2 : 1
            border.color: chip.current ? T.textPrimary : T.border

            Item {
                anchors.fill: parent
                opacity: chip.preset.inCycle ? 1 : T.disabledOpacity

                Item {
                    x: T.paddingCompact + chip.drawing.x
                    y: T.paddingCompact + chip.drawing.y
                    width: chip.drawing.w
                    height: chip.drawing.h

                    // The page itself, so a blank preset still shows its shape.
                    Rectangle {
                        anchors.fill: parent
                        radius: T.radiusSmall
                        color: "transparent"
                        border.width: 1
                        border.color: T.borderStrong
                    }

                    Repeater {
                        model: chip.drawing.rects

                        delegate: Rectangle {
                            required property var modelData

                            x: modelData.x
                            y: modelData.y
                            width: modelData.w
                            height: modelData.h
                            radius: T.radiusSmall / 2
                            color: T.textCaption
                        }
                    }
                }
            }

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: bar.ed.selectPreset(chip.preset.id)
            }

            DragHandler {
                id: dragger

                target: null
                yAxis.enabled: false
                onTranslationChanged: chip.dragDx = active ? translation.x : 0
                onActiveChanged: {
                    if (active)
                        return ;
                    const to = Math.max(0, Math.min(bar.ed.presetCount - 1, Math.round(chip.index + chip.dragDx / bar.step)));
                    chip.dragDx = 0;
                    if (to !== chip.index)
                        bar.ed.movePreset(chip.index, to);
                }
            }

            // The eye: in the cycle (hover only) or out of it (always shown, the chip is dimmed).
            Rectangle {
                id: eye

                visible: chip.near || !chip.preset.inCycle
                x: parent.width - width + T.editBadge / 4
                y: -T.editBadge / 3
                width: T.editBadge
                height: T.editBadge
                radius: width / 2
                color: eyeArea.containsMouse ? T.chip : T.raised
                border.width: 1
                border.color: T.borderStrong

                ThemeGlyph {
                    anchors.centerIn: parent
                    width: T.fontBody
                    height: T.fontBody
                    names: chip.preset.inCycle ? ["view-visible-symbolic", "visibility-symbolic", "view-visible"] : ["view-hidden-symbolic", "hint-symbolic", "view-hidden"]
                    color: chip.preset.inCycle ? T.textCaption : T.textPrimary
                }

                MouseArea {
                    id: eyeArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.ed.toggleCycle(chip.preset.id)
                }
            }

            RemoveBadge {
                id: removeBadge

                visible: chip.near
                x: -T.editBadge / 3
                y: -T.editBadge / 3
                tooltip: bar.app.strings.editRemovePreset
                onClicked: bar.ed.removePreset(chip.preset.id)
            }
        }
    }

    Rectangle {
        id: gear

        readonly property bool current: bar.ed.view === "gear"

        x: bar.ed.presetCount * bar.step
        width: T.editChipW
        height: T.editChipH
        radius: T.radiusInner / 2
        color: gearHover.hovered ? T.chip : T.raised
        border.width: gear.current ? 2 : 1
        border.color: gear.current ? T.textPrimary : T.border

        ThemeGlyph {
            anchors.centerIn: parent
            width: T.iconTransport
            height: T.iconTransport
            names: ["configure-symbolic", "preferences-system-symbolic", "configure"]
            color: T.textPrimary
        }

        HoverHandler {
            id: gearHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: bar.ed.selectGear()
        }
    }

    // "+ New": disabled at three presets, with the count beside it.
    Item {
        x: (bar.ed.presetCount + 1) * bar.step
        width: T.editChipW
        height: T.editChipH
        opacity: bar.ed.canAddPreset ? 1 : T.disabledOpacity

        DashedBox {
            anchors.fill: parent
            radius: T.radiusInner / 2
            stroke: newHover.hovered && bar.ed.canAddPreset ? T.textCaption : T.borderStrong
        }

        PlasmaLabel {
            anchors.centerIn: parent
            text: "+"
            color: T.textPrimary
            font.pixelSize: T.fontTitle
        }

        HoverHandler {
            id: newHover

            enabled: bar.ed.canAddPreset
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: bar.ed.canAddPreset
            onTapped: bar.ed.addPreset()
        }
    }

    PlasmaLabel {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: bar.app.strings.editPresetCount(bar.ed.presetCount, bar.ed.maxPresets)
        color: T.textSecondary
        font.pixelSize: T.fontCaption
    }
}
