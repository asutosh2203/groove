pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast

// Weather 4x1 (D-55, Wide page only): the left block, a hairline, then an hourly strip from Now, with the next sun event as
// its own column at its time. How many columns fit comes from the box.
WeatherBase {
    id: view

    readonly property real areaX: view.cellWidth + T.gap
    readonly property real areaWidth: view.boxWidth - view.areaX - T.widgetPadding
    readonly property int count: Math.max(1, Math.floor(view.areaWidth / T.widgetDayColumn))
    readonly property var cells: view.fc && view.service ? Forecast.strip(view.fc, view.nowMs, { "t": view.service.temperatureC, "code": view.service.weatherCode, "isDay": view.service.isDay }, view.count) : []

    LeftBlock {
        width: view.cellWidth
        height: parent.height
        base: view
    }

    Rectangle {
        x: view.cellWidth + T.gap / 2
        y: T.widgetPadding
        width: 1
        height: view.boxHeight - 2 * T.widgetPadding
        color: T.borderStrong
    }

    Repeater {
        model: view.cells.length

        delegate: HourColumn {
            id: hour

            required property int index

            x: view.areaX + hour.index * (view.areaWidth / view.count) + (view.areaWidth / view.count - hour.width) / 2
            anchors.verticalCenter: parent.verticalCenter
            cell: view.cells[hour.index]
            timeText: view.cells[hour.index].kind === "now" && view.strings ? view.strings.now : view.hm(view.cells[hour.index].ms, view.offset)
            sunText: view.strings ? (view.cells[hour.index].sun === "sunrise" ? view.strings.sunrise : view.strings.sunset) : ""
            fahrenheit: view.fahrenheit
        }
    }
}
