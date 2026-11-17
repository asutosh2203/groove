pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClockFormat.js" as ClockFormat
import "../../logic/WeatherCodes.js" as Codes
import "../../logic/WeatherForecast.js" as Forecast
import "../../logic/WidgetState.js" as WidgetState

// What the three Weather views share (D-55): the service, the data, the state and the click. A view lays out from its box
// and span only.
Widgets.WidgetView {
    id: base

    readonly property var service: base.services.weather
    readonly property bool configured: !!base.service && base.service.configured
    readonly property var fc: base.service ? base.service.forecast : null
    readonly property bool wantsForecast: base.span !== "1x1"
    readonly property bool hasData: !!base.service && base.service.hasData && (!base.wantsForecast || base.fc !== null)
    readonly property bool fahrenheit: base.settings.units === "follow" ? (!!base.service && base.service.fahrenheit) : base.settings.units === "fahrenheit"
    // Sampled when the view opens and when new data arrives; a page is only on screen briefly.
    property double nowMs: Date.now()
    readonly property int cols: base.span === "4x1" ? 4 : base.span === "2x1" ? 2 : 1
    // The width of one cell, from the box and the span (never a fixed number): the 1x1 left block of every span.
    readonly property real cellWidth: (base.boxWidth - T.gap * (base.cols - 1)) / base.cols
    readonly property string condition: base.strings && base.service ? base.strings.condition(Codes.conditionKey(base.service.weatherCode, base.service.isDay)) : ""
    readonly property real offset: base.fc ? base.fc.offset : 0

    function hm(ms, offset) {
        return ClockFormat.timeText(ms, offset, "locale", base.use24Hour, base.locale.amText, base.locale.pmText);
    }

    // An hourly column's label: "9 pm" in 12-hour, the full time in 24-hour.
    function hourLabel(ms) {
        return ClockFormat.hourText(ms, base.offset, "locale", base.use24Hour, base.locale.amText, base.locale.pmText);
    }

    // The detail line for a setting ("highlow" or "sun") as { head, glyph, tail }.
    function detailFor(setting) {
        return Forecast.detail(setting, { "condition": base.condition, "today": base.fc ? Forecast.today(base.fc, base.nowMs) : null, "sun": base.fc ? Forecast.nextSun(base.fc, base.nowMs) : null, "fahrenheit": base.fahrenheit, "offset": base.offset }, base.hm);
    }

    widgetState: WidgetState.state({ "needsSetup": !!base.service ? !base.service.configured : false, "hasData": base.hasData, "busy": !!base.service && base.service.busy, "failing": !!base.service && base.service.failing, "updatedMs": base.service ? base.service.updatedMs : 0, "now": base.nowMs })
    lastUpdated: base.service ? base.service.updatedMs : 0
    clickAction: base.configured ? ({ "type": "url", "value": base.service.forecastUrl }) : null

    readonly property double dataStamp: base.service ? base.service.updatedMs : 0

    onDataStampChanged: base.nowMs = Date.now()
}
