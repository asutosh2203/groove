pragma ComponentBehavior: Bound

import QtQuick

MaskedArtwork {
    id: self

    required property var app

    artworkSource: self.app.media.hasPlayer ? self.app.media.player.artUrl : ""
    cornerRadius: self.app.notchShape ? Math.round(Math.min(width, height) * 0.3) : Math.min(width, height) / 2 // notch: rounded square like expanded; pill: circle
    mode: "media"
    progress: self.app.activities.progressValueFor("media") / Math.max(1, self.app.activities.progressToFor("media"))
    playing: self.app.media.isPlaying
}
