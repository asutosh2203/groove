pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter/Tokens.js" as T
import "../widgets/pomodoro" as Pomodoro

// A Pomodoro timer as a Live tile (D-64): the widget's own 1x1 face (phase, ring and time, round, play and pause) with a skip
// button beside it. The timer lives in the service, so the tile and the widget always agree. Nothing here ticks by itself.
Rectangle {
    id: tile

    required property var app
    required property string pid

    radius: T.radiusInner
    color: T.row

    Pomodoro.View1x1 {
        id: face

        anchors.fill: parent
        services: ({ "timer": tile.app.timers })
        pid: tile.pid
        strings: tile.app.strings
        reduceMotion: tile.app.reduceMotion

        Pomodoro.GlyphButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: T.widgetPadding - 6
            anchors.rightMargin: T.widgetPadding - 6 + T.widgetButton * (face.paused ? 2 : 1)
            iconName: "media-skip-forward"
            tooltipText: tile.app.strings.pomodoroSkip
            onClicked: tile.app.timers.skip(tile.pid)
        }
    }
}
