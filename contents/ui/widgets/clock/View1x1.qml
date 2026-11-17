pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClockFormat.js" as ClockFormat

// Clock 1x1 (D-55): city, HH:mm, date. Changes once a minute with the shared ClockService.
Widgets.WidgetView {
    id: view

    readonly property var clock: view.services.clock
    readonly property string zone: String(view.settings.timezone)
    readonly property string zoneState: view.clock ? view.clock.zoneState(view.zone) : "loading"
    readonly property real offset: view.clock ? view.clock.offsetOf(view.zone) : NaN
    readonly property var dayNames: [0, 1, 2, 3, 4, 5, 6].map(i => view.locale.dayName(i, Locale.ShortFormat))
    readonly property var monthNames: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map(i => view.locale.monthName(i, Locale.ShortFormat))

    widgetState: view.zoneState
    lastUpdated: view.clock ? view.clock.nowMs : 0
    clickAction: ({ "type": "calendar" })
    message: view.zoneState === "error" && view.strings ? view.strings.widgetUnknownZone : ""

    Widgets.TileFace {
        anchors.fill: parent
        anchors.margins: T.widgetPadding
        label: view.settings.label.length > 0 ? view.settings.label : ClockFormat.cityName(view.zone === "local" ? view.clock.localZone : view.zone)
        hero: isFinite(view.offset) ? ClockFormat.timeText(view.clock.nowMs, view.offset, view.settings.timeFormat, view.use24Hour, view.locale.amText, view.locale.pmText) : ""
        detail: isFinite(view.offset) ? ClockFormat.dateText(view.clock.nowMs, view.offset, view.dayNames, view.monthNames) : ""
    }
}
