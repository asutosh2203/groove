import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: musicPage

    property var app: null
    readonly property bool hasPlayer: app && app.hasPlayer
    readonly property bool hasLength: hasPlayer && app.player.length > 0
    readonly property bool playing: hasPlayer && app.isPlaying

    RowLayout {
        id: contentRow

        anchors.fill: parent
        // Shell inset (left wall and bottom edge) is equal so the artwork corner stays concentric with the shell's 26px curve.
        readonly property real inset: app && app.notchShape ? 12 : 10
        anchors.bottomMargin: inset - (app && app.notchShape ? 12 : 8)
        // Artwork sits 2px inside the shell wall; both children share this row's height exactly.
        anchors.leftMargin: -2
        spacing: 12

        ArtworkVisual {
            // Both children take the row's exact height, so top and bottom always coincide.
            Layout.preferredHeight: contentRow.height
            Layout.minimumHeight: contentRow.height
            Layout.maximumHeight: contentRow.height
            Layout.preferredWidth: contentRow.height
            source: musicPage.hasPlayer ? musicPage.app.player.artUrl : ""
            cornerRadius: 26 - contentRow.inset
            fallbackMode: "media"
            progress: musicPage.hasPlayer ? musicPage.app.player.position / Math.max(1, musicPage.app.player.length) : 0
            playing: musicPage.playing
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: contentRow.height
            Layout.minimumHeight: contentRow.height
            Layout.maximumHeight: contentRow.height
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: musicPage.hasPlayer ? musicPage.app.player.track || musicPage.app.player.identity || i18n("Media") : i18n("Media")
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: musicPage.hasPlayer ? musicPage.app.player.artist || musicPage.app.player.album || musicPage.app.player.identity || "" : ""
                        color: "#8d8f99"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                MuteButton {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignTop
                    large: true
                    playing: musicPage.playing
                    app: musicPage.app
                }
            }

            Item {
                Layout.fillHeight: true
            }

            ProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                opacity: musicPage.hasLength ? 1 : 0
                from: 0
                to: Math.max(1, musicPage.hasPlayer ? musicPage.app.player.length : 1)
                value: musicPage.hasPlayer ? musicPage.app.player.position : 0
                accent: "#b4b6bf"
                trackColor: "#25252b"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 0

                PlasmaLabel {
                    Layout.preferredWidth: 36
                    text: musicPage.hasLength ? musicPage.app.formatMediaTime(musicPage.app.player.position) : ""
                    color: "#9a9ca6"
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                }

                Item {
                    Layout.fillWidth: true
                }

                IslandButton {
                    Layout.rightMargin: 8
                    iconName: "media-skip-backward"
                    flat: true
                    glyphSize: 17
                    implicitWidth: 34
                    tooltipText: i18n("Previous")
                    enabled: musicPage.hasPlayer && musicPage.app.player.canGoPrevious
                    onClicked: musicPage.app.mediaPrevious()
                }

                IslandButton {
                    iconName: musicPage.playing ? "media-playback-pause" : "media-playback-start"
                    flat: true
                    glyphSize: 23
                    implicitWidth: 40
                    tooltipText: musicPage.playing ? i18n("Pause") : i18n("Play")
                    enabled: musicPage.hasPlayer && (musicPage.app.player.canPlay || musicPage.app.player.canPause)
                    onClicked: musicPage.app.mediaPlayPause()
                }

                IslandButton {
                    Layout.leftMargin: 8
                    iconName: "media-skip-forward"
                    flat: true
                    glyphSize: 17
                    implicitWidth: 34
                    tooltipText: i18n("Next")
                    enabled: musicPage.hasPlayer && musicPage.app.player.canGoNext
                    onClicked: musicPage.app.mediaNext()
                }

                Item {
                    Layout.fillWidth: true
                }

                PlasmaLabel {
                    Layout.preferredWidth: 36
                    text: musicPage.hasLength ? musicPage.app.formatMediaTime(musicPage.app.player.length) : ""
                    color: "#9a9ca6"
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
