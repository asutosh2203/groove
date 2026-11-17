pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter" as CC
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast
import "../../weather" as Weather

// One column of the hourly strip: time (or "Now"), glyph and temperature. The sun event column shows the sun glyph and the
// word Sunset or Sunrise where the temperature would be.
Column {
    id: col

    required property var cell
    required property string timeText
    required property string sunText
    required property bool fahrenheit

    spacing: T.deckSpacing

    Island.PlasmaLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: col.timeText
        color: col.cell.kind === "now" ? T.textPrimary : T.textSecondary
        font.pixelSize: T.fontCaption
        font.features: ({ "tnum": 1 })
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: T.widgetGlyphSmall
        height: T.widgetGlyphSmall

        Weather.WeatherIcon {
            anchors.fill: parent
            visible: col.cell.kind !== "sun"
            code: col.cell.code
            isDay: col.cell.isDay
        }

        CC.ThemeGlyph {
            anchors.fill: parent
            visible: col.cell.kind === "sun"
            names: col.cell.sun === "sunrise" ? ["weather-sunrise-symbolic", "weather-sunrise", "weather-clear-symbolic"] : ["weather-sunset-symbolic", "weather-sunset", "weather-clear-night-symbolic"]
            color: T.textPrimary
        }
    }

    Island.PlasmaLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: col.cell.kind === "sun" ? col.sunText : Forecast.deg(col.cell.t, col.fahrenheit)
        color: col.cell.kind === "sun" ? T.textSecondary : T.textPrimary
        font.pixelSize: T.fontCaption
        font.features: ({ "tnum": 1 })
    }
}
