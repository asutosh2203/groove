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
    // An accordion row opened in place also shows a chevron that closes it again.
    property bool collapsible: false
    readonly property bool clickable: tile.app.jobClickable(tile.row)
    signal collapse()
    readonly property var meta: tile.app.jobs.meta(tile.row)
    readonly property int percentage: tile.app.jobs.percentage(tile.row)

    radius: T.radiusInner
    color: clickable && hover.hovered ? T.rowHover : T.row

    Behavior on color {
        enabled: !tile.app.reduceMotion

        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    // The body opens the destination in the file manager; only a tile with a usable destination reacts to the pointer.
    HoverHandler {
        id: hover

        enabled: tile.clickable
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: tile.clickable
        onClicked: tile.app.openJob(tile.row)
    }

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

    // Closes an opened accordion row (its own click target).
    Item {
        visible: tile.collapsible
        anchors.top: parent.top
        anchors.right: parent.right
        width: T.deckCapsuleItem
        height: T.deckCapsuleItem
        Accessible.role: Accessible.Button
        Accessible.name: tile.app.strings.jobCollapse

        CC.ThemeGlyph {
            anchors.centerIn: parent
            width: T.deckGlyph
            height: T.deckGlyph
            names: ["go-up-symbolic", "arrow-up", "go-up"]
            color: chevronHover.hovered ? T.textPrimary : T.textTertiary
        }

        HoverHandler {
            id: chevronHover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: tile.collapse()
        }
    }
}
