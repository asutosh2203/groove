pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/Silhouette.js" as Silhouette

// The chips bar at the bottom of the edit mode (D-56): one chip per preset, a tiny silhouette of its layout (no names),
// then the gear chip for the Control Center tiles. It is the navigator: the capsule is hidden while editing.
Row {
    id: bar

    required property var app
    readonly property var ed: bar.app.editor

    spacing: T.gap

    Repeater {
        model: bar.ed.draft.presets.length

        delegate: Rectangle {
            id: chip

            required property int index
            readonly property var preset: bar.ed.draft.presets[chip.index]
            readonly property bool current: bar.ed.view === "preset" && bar.ed.presetId === chip.preset.id
            readonly property var drawing: Silhouette.rects(chip.preset.page, chip.preset.placements.map(p => p.span), { "w": T.editChipW - 2 * T.paddingCompact, "h": T.editChipH - 2 * T.paddingCompact }, { "w": T.deckCellW, "h": T.deckCellH }, T.editSilhouetteGap)

            width: T.editChipW
            height: T.editChipH
            radius: T.radiusInner / 2
            color: chipHover.hovered ? T.chip : T.raised
            border.width: chip.current ? 2 : 1
            border.color: chip.current ? T.textPrimary : T.border
            opacity: chip.preset.inCycle ? 1 : T.disabledOpacity

            Item {
                x: T.paddingCompact + chip.drawing.x
                y: T.paddingCompact + chip.drawing.y
                width: chip.drawing.w
                height: chip.drawing.h

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

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: bar.ed.selectPreset(chip.preset.id)
            }
        }
    }

    Rectangle {
        id: gear

        readonly property bool current: bar.ed.view === "gear"

        width: T.editChipW
        height: T.editChipH
        radius: T.radiusInner / 2
        color: gearHover.hovered ? T.chip : T.raised
        border.width: gear.current ? 2 : 1
        border.color: gear.current ? T.textPrimary : T.border

        Kirigami.Icon {
            anchors.centerIn: parent
            width: T.iconTransport
            height: T.iconTransport
            source: "configure-symbolic"
            fallback: "configure"
            isMask: true
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
}
