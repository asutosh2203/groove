import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter/Tokens.js" as T

// The closed capsule for a Pomodoro timer (D-64): "Focus · 24 min" with the thin bar, whole minutes only (P9). The service's
// coarse clock steps it, so it never renders per second. A timer waiting for play says so and has no bar.
Item {
    id: timerCompact

    property var app: null
    readonly property var capsule: app ? app.timers.capsule : null
    readonly property var snap: capsule ? app.timers.info(app.timers.lead.pid) : null

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: T.compactInsetLeft
        anchors.rightMargin: T.compactInsetRight
        spacing: T.compactGap

        PlasmaLabel {
            Layout.fillWidth: true
            text: timerCompact.capsule ? timerCompact.app.strings.pomodoroCapsule(timerCompact.capsule, timerCompact.snap?.plain ?? false) : ""
            color: T.textPrimary
            font.pixelSize: T.fontCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        ProgressBar {
            visible: timerCompact.capsule !== null && timerCompact.capsule.kind !== "ended"
            Layout.fillWidth: true
            Layout.preferredHeight: T.compactBar
            from: 0
            to: 1
            value: timerCompact.snap ? timerCompact.snap.progress : 0
            accent: T.fill
            trackColor: T.track
        }
    }
}
