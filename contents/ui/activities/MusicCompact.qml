import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: musicCompact

    property var app: null
    readonly property bool hasPlayer: app && app.hasPlayer

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 1
        spacing: 5

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            PlasmaLabel {
                Layout.fillWidth: true
                text: musicCompact.hasPlayer ? musicCompact.app.player.track || musicCompact.app.player.identity || i18n("Media") : i18n("Media")
                color: "#e9e9ef"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            ProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                visible: musicCompact.hasPlayer && musicCompact.app.mediaLength > 0
                from: 0
                to: Math.max(1, musicCompact.hasPlayer ? musicCompact.app.mediaLength : 1)
                value: musicCompact.hasPlayer ? musicCompact.app.player.position : 0
                accent: "#b4b6bf"
                trackColor: "#25252b"
            }
        }

        MuteButton {
            Layout.preferredWidth: 24
            Layout.preferredHeight: Math.min(24, Math.max(14, musicCompact.height - 6))
            Layout.alignment: Qt.AlignVCenter
            app: musicCompact.app
            // The compact pill is covered while a popup is open (Plasma keeps its wrapper "visible" at opacity 0, so
            // visibility can't tell), so its bars stop then instead of repainting the panel for nothing.
            playing: musicCompact.hasPlayer && musicCompact.app.isPlaying && !musicCompact.app.panelHidden
        }
    }
}
