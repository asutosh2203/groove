pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: self

    required property var app

    anchors.fill: parent
    spacing: 10

    Rectangle {
        Layout.preferredWidth: 58
        Layout.preferredHeight: 58
        radius: 16
        color: "transparent"

        MaskedArtwork {
            anchors.fill: parent
            artworkSource: self.app.activities.artworkFor(self.app.popupActivityMode())
            cornerRadius: 16
            glyphSize: 32
            mode: self.app.popupActivityMode()
            progress: self.app.activities.progressValueFor(self.app.popupActivityMode()) / Math.max(1, self.app.activities.progressToFor(self.app.popupActivityMode()))
            playing: self.app.popupActivityMode() === "media" ? self.app.media.isPlaying : self.app.popupActivityMode() === "job" ? !self.app.jobs.isSuspended(self.app.jobs.activeRow()) : false
        }

    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        PlasmaLabel {
            Layout.fillWidth: true
            text: self.app.primaryTextFor(self.app.popupActivityMode())
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.Bold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        PlasmaLabel {
            Layout.fillWidth: true
            text: self.app.secondaryTextFor(self.app.popupActivityMode())
            color: "#9d9da7"
            font.pixelSize: 10
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            visible: self.app.activities.progressVisibleFor(self.app.popupActivityMode())
            from: 0
            to: self.app.activities.progressToFor(self.app.popupActivityMode())
            value: self.app.activities.progressValueFor(self.app.popupActivityMode())
            accent: self.app.activities.progressAccentFor(self.app.popupActivityMode())
        }

    }

    RowLayout {
        visible: self.app.activities.mediaControlsFor(self.app.popupActivityMode())
        spacing: 6

        IslandButton {
            iconName: "media-skip-backward"
            compact: true
            tooltipText: self.app.strings.previous
            enabled: self.app.media.player && self.app.media.player.canGoPrevious
            onClicked: self.app.media.previous()
        }

        IslandButton {
            iconName: self.app.media.isPlaying ? "media-playback-pause" : "media-playback-start"
            compact: true
            emphasized: true
            tooltipText: self.app.media.isPlaying ? self.app.strings.pause : self.app.strings.play
            enabled: self.app.media.player && (self.app.media.player.canPlay || self.app.media.player.canPause)
            onClicked: self.app.media.playPause()
        }

        IslandButton {
            iconName: "media-skip-forward"
            compact: true
            tooltipText: self.app.strings.next
            enabled: self.app.media.player && self.app.media.player.canGoNext
            onClicked: self.app.media.next()
        }

    }

}
