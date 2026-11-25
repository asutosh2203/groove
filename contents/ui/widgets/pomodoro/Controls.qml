pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T

// Skip and reset (D-64), shared by the 2x1 and 4x1.
Row {
    id: controls

    required property var base

    spacing: T.deckSpacing

    GlyphButton {
        objectName: "skip"
        iconName: "media-skip-forward"
        tooltipText: controls.base.s.pomodoroSkip
        enabled: !controls.base.ready
        onClicked: controls.base.hub.skip(controls.base.pid)
    }

    GlyphButton {
        objectName: "reset"
        iconName: "view-refresh"
        tooltipText: controls.base.s.pomodoroReset
        enabled: !controls.base.ready
        onClicked: controls.base.hub.reset(controls.base.pid)
    }
}
