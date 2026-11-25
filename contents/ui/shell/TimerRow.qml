pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/LiveGlyphs.js" as LiveGlyphs
import "../logic/PomodoroEngine.js" as Engine
import "../widgets/pomodoro" as Pomodoro

// A Pomodoro timer as a compact row of the Live list (D-64): glyph, phase, time and play or pause.
Rectangle {
    id: row

    required property var app
    required property string pid
    readonly property var snap: row.app.timers.info(row.pid)

    implicitHeight: T.liveRowHeight
    radius: T.radiusInner
    color: T.row

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: T.widgetPadding
        anchors.rightMargin: T.liveBadgeRow

        CC.ThemeGlyph {
            Layout.preferredWidth: T.fontBody
            Layout.preferredHeight: T.fontBody
            names: LiveGlyphs.chain("timer")
            color: T.textPrimary
        }

        PlasmaLabel {
            Layout.fillWidth: true
            text: row.snap ? row.app.strings.pomodoroPhase(row.snap.status === "ended" ? row.snap.endedKind : row.snap.kind === "ready" ? "focus" : row.snap.kind, row.snap.plain) : ""
            color: T.textPrimary
            font.pixelSize: T.fontBody
            elide: Text.ElideRight
        }

        PlasmaLabel {
            text: row.snap ? (row.snap.status === "ended" ? "0:00" : Engine.mmss(row.snap.remainingMs)) : ""
            color: T.textCaption
            font.pixelSize: T.fontCaption
            font.features: ({ "tnum": 1 })
        }

        Pomodoro.GlyphButton {
            iconName: row.snap?.status === "running" ? "media-playback-pause" : "media-playback-start"
            tooltipText: row.snap?.status === "running" ? row.app.strings.pomodoroPause : row.app.strings.pomodoroPlay
            onClicked: row.app.timers.toggle(row.pid)
        }
    }
}
