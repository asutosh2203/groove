import QtQuick
import QtQuick.Layouts
import ".."
import "../logic/MediaPlayers.js" as MediaPlayers
import "../controlcenter/Tokens.js" as T

Item {
    id: musicPage

    property var app: null
    readonly property bool hasPlayer: app && app.media.hasPlayer
    readonly property bool hasLength: hasPlayer && app.media.length > 0
    readonly property bool playing: hasPlayer && app.media.isPlaying
    // The artwork and the title block raise the player; the buttons and the bar keep their own behaviour.
    readonly property bool raiseHover: artRaise.hovered || titleRaise.hovered || artistRaise.hovered

    RowLayout {
        id: contentRow

        anchors.fill: parent
        // The page pads every side equally, so the artwork sits flush with that padding and its corner is concentric with the
        // shell's curve (shell radius minus the padding).
        readonly property real inset: T.deckPadding
        spacing: 12

        ArtworkVisual {
            // Both children take the row's exact height, so top and bottom always coincide.
            Layout.preferredHeight: contentRow.height
            Layout.minimumHeight: contentRow.height
            Layout.maximumHeight: contentRow.height
            Layout.preferredWidth: contentRow.height
            source: musicPage.app.media.artUrl
            kind: musicPage.app.media.kind
            cornerRadius: (musicPage.app ? musicPage.app.popupRadius : 26) - contentRow.inset
            fallbackMode: "media"
            progress: musicPage.hasPlayer ? musicPage.app.media.player.position / Math.max(1, musicPage.app.media.length) : 0
            playing: musicPage.playing
            scale: musicPage.raiseHover ? T.hoverScale : 1

            Behavior on scale {
                enabled: !musicPage.app.reduceMotion

                NumberAnimation {
                    duration: T.motionHover
                    easing.type: T.easingStandard
                }
            }

            RaiseArea {
                id: artRaise

                onActivated: musicPage.app.raisePlayer()
            }
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
                        text: musicPage.hasPlayer ? musicPage.app.media.player.track || musicPage.app.media.player.identity || i18n("Media") : i18n("Media")
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        RaiseArea {
                            id: titleRaise

                            onActivated: musicPage.app.raisePlayer()
                        }
                    }

                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: musicPage.hasPlayer ? musicPage.app.media.player.artist || musicPage.app.media.player.album || musicPage.app.media.player.identity || "" : ""
                        color: "#8d8f99"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        RaiseArea {
                            id: artistRaise

                            onActivated: musicPage.app.raisePlayer()
                        }
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
                to: Math.max(1, musicPage.hasPlayer ? musicPage.app.media.length : 1)
                value: musicPage.hasPlayer ? musicPage.app.media.player.position : 0
                accent: "#b4b6bf"
                trackColor: "#25252b"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 0

                PlasmaLabel {
                    Layout.preferredWidth: 30
                    text: musicPage.hasLength ? MediaPlayers.formatTime(musicPage.app.media.player.position) : ""
                    color: "#9a9ca6"
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                }

                Item {
                    Layout.fillWidth: true
                }

                IslandButton {
                    Layout.rightMargin: 2
                    iconName: "media-skip-backward"
                    flat: true
                    glyphSize: T.iconTransport
                    implicitWidth: 34
                    // No hover tooltip; screen readers still get the name.
                    Accessible.name: i18n("Previous")
                    enabled: musicPage.hasPlayer && musicPage.app.media.player.canGoPrevious
                    onClicked: musicPage.app.media.previous()
                }

                IslandButton {
                    iconName: musicPage.playing ? "media-playback-pause" : "media-playback-start"
                    flat: true
                    glyphSize: T.iconTransportPrimary
                    implicitWidth: 40
                    Accessible.name: musicPage.playing ? i18n("Pause") : i18n("Play")
                    enabled: musicPage.hasPlayer && (musicPage.app.media.player.canPlay || musicPage.app.media.player.canPause)
                    onClicked: musicPage.app.media.playPause()
                }

                IslandButton {
                    Layout.leftMargin: 2
                    iconName: "media-skip-forward"
                    flat: true
                    glyphSize: T.iconTransport
                    implicitWidth: 34
                    Accessible.name: i18n("Next")
                    enabled: musicPage.hasPlayer && musicPage.app.media.player.canGoNext
                    onClicked: musicPage.app.media.next()
                }

                Item {
                    Layout.fillWidth: true
                }

                PlasmaLabel {
                    Layout.preferredWidth: 30
                    text: musicPage.hasLength ? MediaPlayers.formatTime(musicPage.app.media.length) : ""
                    color: "#9a9ca6"
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
