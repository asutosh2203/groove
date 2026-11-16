pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T

// The compact face of a job: the same glyph the expanded view shows (JobExpanded).
Item {
    id: self

    required property var app
    readonly property var glyphNames: self.app.jobs.glyphNames(self.app.jobs.activeRow())

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
        names: self.glyphNames
        color: T.iconIdle
    }
}
