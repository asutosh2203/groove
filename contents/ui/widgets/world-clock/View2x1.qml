pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClockFormat.js" as ClockFormat

// World Clock 2x1 (D-55): three cities side by side, split by hairlines. Each shows city, time and "Today · -5:30" against
// local time (or Tomorrow / Yesterday when its date differs). No sun or moon: only the time zone is known, not the place.
Widgets.WidgetView {
    id: view

    readonly property var clock: view.services.clock
    readonly property var zoneIds: [view.settings.timezone1, view.settings.timezone2, view.settings.timezone3].map(String)
    readonly property var zoneStates: view.zoneIds.map(zone => view.clock ? view.clock.zoneState(zone) : "loading")
    readonly property real columnWidth: (view.boxWidth - 2 * T.widgetPadding) / 3

    widgetState: view.zoneStates.indexOf("error") >= 0 ? "error" : view.zoneStates.indexOf("loading") >= 0 ? "loading" : "ready"
    lastUpdated: view.clock ? view.clock.nowMs : 0
    message: view.strings ? view.strings.widgetUnknownZone : ""

    Repeater {
        model: 3

        delegate: Item {
            id: column

            required property int index
            readonly property string zone: view.zoneIds[column.index]
            readonly property real offset: view.clock ? view.clock.offsetOf(column.zone) : NaN
            readonly property bool known: isFinite(column.offset)
            readonly property var parts: column.known ? ClockFormat.timeParts(view.clock.nowMs, column.offset, view.settings.timeFormat, view.use24Hour, view.locale.amText, view.locale.pmText) : ({ "digits": "", "suffix": "" })

            x: T.widgetPadding + column.index * view.columnWidth
            y: T.widgetPadding
            width: view.columnWidth
            height: view.boxHeight - 2 * T.widgetPadding

            Rectangle {
                visible: column.index > 0
                x: 0
                width: 1
                height: parent.height
                color: T.borderStrong
            }

            Widgets.TileFace {
                anchors.fill: parent
                anchors.leftMargin: column.index > 0 ? T.widgetPadding : 0
                anchors.rightMargin: column.index < 2 ? T.widgetPadding : 0
                heroSize: T.widgetHeroSizeSmall
                label: column.zone === "local" && view.clock.localLabel.length > 0 ? view.clock.localLabel : ClockFormat.cityName(column.zone === "local" ? view.clock.localZone : column.zone)
                hero: column.parts.digits
                heroSuffix: column.parts.suffix
                detail: column.known && view.strings ? view.strings.dayRelation(ClockFormat.dayRelation(view.clock.nowMs, column.offset, view.clock.localOffset)) + " · " + ClockFormat.offsetText(column.offset, view.clock.localOffset) : ""
            }
        }
    }
}
