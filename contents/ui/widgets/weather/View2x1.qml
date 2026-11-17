pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast

// Weather 2x1 (D-55): the left block, a hairline, then five day columns starting today. The day area is whatever the box
// leaves after the left block.
WeatherBase {
    id: view

    readonly property var days: view.fc ? Forecast.days(view.fc, view.nowMs, 5) : []
    readonly property real areaX: view.cellWidth + T.gap
    readonly property real areaWidth: view.boxWidth - view.areaX - T.widgetPadding

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
        model: view.days.length

        delegate: DayColumn {
            id: column

            required property int index

            x: view.areaX + column.index * (view.areaWidth / 5) + (view.areaWidth / 5 - column.width) / 2
            anchors.verticalCenter: view.verticalCenter
            day: view.days[column.index]
            dayName: view.days[column.index].isToday && view.strings ? view.strings.today : view.locale.dayName(view.days[column.index].dow, Locale.ShortFormat)
            fahrenheit: view.fahrenheit
        }
    }
}
