import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter/Tokens.js" as T

Item {
    id: jobCompact

    property var app: null
    readonly property int row: app ? app.jobs.activeRow() : -1
    readonly property int percentage: app ? app.jobs.percentage(row) : -1
    readonly property bool suspended: app ? app.jobs.isSuspended(row) : false

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 2
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            PlasmaLabel {
                Layout.fillWidth: true
                text: jobCompact.row >= 0 ? jobCompact.app.jobTitle(jobCompact.row) : i18n("Working")
                color: T.textPrimary
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                visible: jobCompact.percentage >= 0 || jobCompact.suspended
                text: jobCompact.suspended ? jobCompact.app.jobMetaText(jobCompact.row) : jobCompact.percentage + "%"
                color: T.textCaption
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            from: 0
            to: 100
            value: Math.max(0, jobCompact.percentage)
            accent: T.fill
            trackColor: T.track
            tipGradient: true
            glow: true
            dimmed: jobCompact.suspended
        }
    }
}
