import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T

Item {
    id: jobPage

    property var app: null
    property int row: app ? app.jobs.activeRow() : -1
    readonly property int percentage: app ? app.jobs.percentage(row) : -1
    readonly property bool suspended: app ? app.jobs.isSuspended(row) : false
    readonly property var glyphNames: app ? app.jobs.glyphNames(row) : ["folder-download-symbolic"]

    // Muted manage-zone icon that brightens on hover, like the notification's open and dismiss glyphs.
    component GhostIcon: Item {
        id: ghost

        property var names: []
        property string tooltipText: ""

        signal clicked()

        implicitWidth: 16
        implicitHeight: 16
        Accessible.role: Accessible.Button
        Accessible.name: tooltipText
        Accessible.onPressAction: clicked()

        CC.ThemeGlyph {
            anchors.fill: parent
            names: ghost.names
            color: area.containsMouse ? T.textPrimary : T.textTertiary

            Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: T.easingStandard } }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ghost.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
            radius: T.radiusInner
            color: T.card
            border.color: T.border
            border.width: 1

            CC.ThemeGlyph {
                anchors.centerIn: parent
                width: 24
                height: 24
                names: jobPage.glyphNames
                color: T.iconIdle
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: jobPage.row >= 0 ? jobPage.app.jobTitle(jobPage.row) : i18n("Working")
                    color: T.textPrimary
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                GhostIcon {
                    visible: jobPage.row >= 0 && jobPage.app.jobs.suspendable(jobPage.row)
                    names: jobPage.suspended ? ["media-playback-start-symbolic", "media-playback-start"] : ["media-playback-pause-symbolic", "media-playback-pause"]
                    tooltipText: jobPage.suspended ? i18n("Resume") : i18n("Pause")
                    onClicked: jobPage.app.jobs.toggleSuspended(jobPage.row)
                }

                GhostIcon {
                    visible: jobPage.row >= 0 && jobPage.app.jobs.killable(jobPage.row)
                    names: ["window-close-symbolic", "dialog-close", "window-close"]
                    tooltipText: i18n("Cancel")
                    onClicked: jobPage.app.jobs.cancel(jobPage.row)
                }
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: jobPage.row >= 0 ? jobPage.app.jobSubtitle(jobPage.row) : ""
                color: T.textSecondary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            ProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                Layout.topMargin: 2
                from: 0
                to: 100
                value: Math.max(0, jobPage.percentage)
                accent: T.fill
                trackColor: T.track
                tipGradient: true
                glow: true
                dimmed: jobPage.suspended
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: jobPage.row >= 0 ? jobPage.app.jobMetaText(jobPage.row) : ""
                    color: T.textTertiary
                    font.pixelSize: T.fontCaption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    visible: jobPage.percentage >= 0
                    text: jobPage.percentage + "%"
                    color: T.textCaption
                    font.pixelSize: T.fontCaption
                    font.weight: Font.Bold
                }
            }
        }
    }
}
