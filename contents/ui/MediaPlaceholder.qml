pragma ComponentBehavior: Bound

import QtQuick
import "controlcenter" as CC
import "controlcenter/Tokens.js" as T

// Neutral stand-in for missing artwork (D-45, D-26): the job tile's style with a muted music note or film glyph.
Item {
    id: placeholder

    property string kind: "music"
    property real cornerRadius: Math.min(width, height) / 2
    readonly property var names: kind === "video" ? ["video-x-generic-symbolic", "emblem-videos-symbolic", "camera-video-symbolic"] : ["audio-x-generic-symbolic", "emblem-music-symbolic", "folder-music-symbolic"]

    Rectangle {
        anchors.fill: parent
        radius: placeholder.cornerRadius
        color: T.card
        border.color: T.border
        border.width: 1
    }

    CC.ThemeGlyph {
        anchors.centerIn: parent
        width: Math.round(Math.min(placeholder.width, placeholder.height) * 0.46)
        height: width
        names: placeholder.names
        color: T.iconIdle
    }
}
