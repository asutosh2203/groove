pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T

// One job as a full tile (D-51, D-46 style): kind glyph, title, app and destination, progress, speed, percent and time left.
// It fills whatever slot it is given.
Rectangle {
    id: tile

    required property var app
    required property int row
    readonly property var meta: tile.app.jobs.meta(tile.row)
    readonly property int percentage: tile.app.jobs.percentage(tile.row)

    radius: T.radiusInner
    color: T.row

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: T.liveTilePadding
        spacing: T.liveGap

        RowLayout {
            Layout.fillWidth: true
            spacing: T.liveGap

            Rectangle {
                Layout.preferredWidth: T.liveChip
                Layout.preferredHeight: T.liveChip
                radius: T.radiusInner
                color: T.card
                border.color: T.border
                border.width: 1

                CC.ThemeGlyph {
                    anchors.centerIn: parent
                    width: T.liveGlyph
                    height: T.liveGlyph
                    names: tile.app.jobs.glyphNames(tile.row)
                    color: T.iconIdle
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: tile.app.jobTitle(tile.row)
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: tile.app.jobSubtitle(tile.row)
                    color: T.textSecondary
                    font.pixelSize: T.fontCaption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: T.liveRowBar
            from: 0
            to: 100
            value: Math.max(0, tile.percentage)
            accent: T.fill
            trackColor: T.track
            tipGradient: true
            glow: true
            dimmed: tile.app.jobs.isSuspended(tile.row)
        }

        RowLayout {
            Layout.fillWidth: true

            PlasmaLabel {
                Layout.fillWidth: true
                text: tile.app.strings.jobSpeed(tile.meta)
                color: T.textTertiary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
            }

            PlasmaLabel {
                text: tile.app.strings.jobProgress(tile.percentage, tile.meta.kind === "speed" ? tile.meta.remaining : -1)
                color: T.textCaption
                font.pixelSize: T.fontCaption
            }
        }
    }
}
