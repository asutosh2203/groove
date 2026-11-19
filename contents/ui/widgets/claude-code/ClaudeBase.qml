pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClaudeWidget.js" as Claude
import "../../logic/ClockFormat.js" as ClockFormat

// What both Claude Code views share (D-60): the service's facts, the 1x1 face derived from them, and time and day text.
// Budget and outcomes only; Live owns progress.
Widgets.WidgetView {
    id: base

    readonly property var agents: base.services.agents
    // Sampled when the view opens, on every snapshot and once a minute (for "resets 18:40" and "18 min ago").
    property double nowMs: Date.now()
    readonly property var facts: base.agents ? ({ "usage": base.agents.usage, "sawLimits": base.agents.sawLimits, "spend": base.agents.spend, "sessions": base.agents.sessions, "recent": base.agents.recent }) : ({ "usage": {}, "sawLimits": false, "spend": {}, "sessions": [], "recent": [] })
    readonly property var face: Claude.face(base.facts, base.nowMs)
    // Usage not reported for a while (D-60): the host shows "updated N min ago" in place of the detail line (D-55).
    widgetState: base.face.stale ? "stale" : "ready"
    lastUpdated: base.face.usageAt
    readonly property int cols: base.span === "2x1" ? 2 : 1
    readonly property real cellWidth: (base.boxWidth - T.gap * (base.cols - 1)) / base.cols
    readonly property double stamp: base.agents ? base.agents.nowMs : 0

    function localTime(ms) {
        return ClockFormat.timeText(ms, -new Date(ms).getTimezoneOffset() * 60, "locale", base.use24Hour, base.locale.amText, base.locale.pmText);
    }

    function dayOf(ms) {
        return base.locale.dayName(new Date(ms).getDay(), Locale.ShortFormat);
    }

    onStampChanged: base.nowMs = Date.now()

    Timer {
        interval: T.minuteTick
        repeat: true
        running: true
        onTriggered: base.nowMs = Date.now()
    }
}
