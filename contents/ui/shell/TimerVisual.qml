pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/LiveGlyphs.js" as LiveGlyphs

// The compact face of a Pomodoro timer (D-64): the timer glyph, with a small dot while it waits for play.
Item {
    id: self

    required property var app
    readonly property var capsule: self.app.timers.capsule

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: T.card
        border.color: T.border
        border.width: 1
    }

    CC.ThemeGlyph {
        anchors.fill: parent
        anchors.margins: Math.max(3, self.width * 0.22)
        names: LiveGlyphs.chain("timer")
        color: T.iconIdle
    }

    Rectangle {
        visible: self.capsule?.dot ?? false
        width: Math.max(T.liveBadge, self.width * 0.26)
        height: width
        radius: width / 2
        color: T.textPrimary
        anchors.top: parent.top
        anchors.right: parent.right
    }
}
