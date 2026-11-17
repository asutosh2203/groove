pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T

// The jobs as a list (D-51): a summary header, then compact rows (name, percent, thin bar). It scrolls when the rows
// overflow, with a fade where more lie beyond.
Item {
    id: list

    required property var app
    required property var model
    required property var header

    ColumnLayout {
        anchors.fill: parent
        spacing: T.liveGap

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: T.liveHeaderHeight
            spacing: T.liveGap

            CC.ThemeGlyph {
                visible: !list.header.rowGlyphs
                Layout.preferredWidth: T.fontBody
                Layout.preferredHeight: T.fontBody
                names: list.model.count > 0 ? list.app.jobs.glyphNames(list.model.get(0).row) : ["folder-download-symbolic"]
                color: T.textPrimary
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: list.app.strings.liveHeader(list.header.kind, list.header.count)
                color: T.textPrimary
                font.pixelSize: T.fontBody
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            PlasmaLabel {
                text: list.app.strings.jobProgress(list.header.percent, list.header.remaining)
                color: T.textCaption
                font.pixelSize: T.fontCaption
            }
        }

        ListView {
            id: rows

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: T.liveGap
            boundsBehavior: Flickable.StopAtBounds
            model: list.model

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: T.motionFade
                    easing.type: T.easingStandard
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: T.motionFade
                    easing.type: T.easingStandard
                }
            }

            delegate: Rectangle {
                id: entry

                required property int row
                readonly property int percentage: list.app.jobs.percentage(entry.row)

                width: ListView.view.width
                height: T.liveRowHeight
                radius: T.radiusInner
                color: T.row

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: T.liveTilePadding
                    anchors.rightMargin: T.liveTilePadding
                    anchors.topMargin: T.deckSpacing
                    anchors.bottomMargin: T.deckSpacing
                    spacing: T.liveGap

                    CC.ThemeGlyph {
                        visible: list.header.rowGlyphs
                        Layout.preferredWidth: T.fontBody
                        Layout.preferredHeight: T.fontBody
                        names: list.app.jobs.glyphNames(entry.row)
                        color: T.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: T.deckSpacing

                        PlasmaLabel {
                            Layout.fillWidth: true
                            text: list.app.jobTitle(entry.row)
                            color: T.textPrimary
                            font.pixelSize: T.fontCaption
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        ProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: T.liveRowBar
                            from: 0
                            to: 100
                            value: Math.max(0, entry.percentage)
                            accent: T.fill
                            trackColor: T.track
                            dimmed: list.app.jobs.isSuspended(entry.row)
                        }
                    }

                    PlasmaLabel {
                        text: entry.percentage >= 0 ? entry.percentage + "%" : ""
                        color: T.textCaption
                        font.pixelSize: T.fontCaption
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: T.liveFade
        visible: rows.contentHeight - rows.contentY - rows.height > 1
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: T.dialog
            }
        }
    }
}
