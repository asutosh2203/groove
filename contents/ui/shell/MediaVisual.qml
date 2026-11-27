pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../logic/DiscSpin.js" as Disc

MaskedArtwork {
    id: self

    required property var app
    // D-68: the Pill's artwork is a disc; the held angle lives in the media service, so a view recreated after a
    // notification resumes where it stopped.
    readonly property bool disc: !self.app.notchShape && self.hasArtwork && self.app.media.kind === "music"
    readonly property string trackKey: self.app.media.hasPlayer ? [self.app.media.player.key, self.app.media.player.track, self.app.media.player.artist].join("|") : ""
    readonly property bool spinning: Disc.spinWanted({ "pill": !self.app.notchShape, "playing": self.playing, "artworkReady": self.hasArtwork, "kind": self.app.media.kind, "panelHidden": self.app.panelHidden, "reduceMotion": self.app.reduceMotion })

    function sync() {
        self.app.media.disc.advance(self.trackKey, self.spinning, Date.now());
    }

    artworkSource: self.app.media.artUrl
    cornerRadius: self.app.notchShape ? Math.round(Math.min(width, height) * 0.3) : Math.min(width, height) / 2 // notch: rounded square like expanded; pill: circle
    mode: "media"
    kind: self.app.media.placeholderKind
    progress: self.app.activities.progressValueFor("media") / Math.max(1, self.app.activities.progressToFor("media"))
    playing: self.app.media.isPlaying
    rotation: self.disc ? self.app.media.disc.angleFor(self.trackKey) : 0
    onSpinningChanged: self.sync()
    onTrackKeyChanged: self.sync()
    Component.onCompleted: self.sync()

    DecorClockLease {
        clock: self.app.decorClock
        active: self.spinning
        fps: Disc.fps
    }

    Connections {
        function onTimeChanged() {
            self.sync();
        }

        target: self.app.decorClock
        enabled: self.spinning
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.2
        height: width
        radius: width / 2
        color: "#0b0b0e"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.35)
        visible: self.disc
    }
}
