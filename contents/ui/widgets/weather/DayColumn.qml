pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast

// One day of the 2x1 forecast: day name, condition glyph, high in white and low in grey.
Column {
    id: col

    required property var day
    required property string dayName
    required property bool fahrenheit

    spacing: T.deckSpacing

    Island.PlasmaLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: col.dayName
        color: T.textSecondary
        font.pixelSize: T.fontCaption
    }

    WeatherGlyph {
        anchors.horizontalCenter: parent.horizontalCenter
        width: T.widgetGlyphSmall
        height: T.widgetGlyphSmall
        code: col.day.code
        isDay: true
    }

    Island.PlasmaLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Forecast.deg(col.day.max, col.fahrenheit)
        color: T.textPrimary
        font.pixelSize: T.fontCaption
        font.features: ({ "tnum": 1 })
    }

    Island.PlasmaLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Forecast.deg(col.day.min, col.fahrenheit)
        color: T.textSecondary
        font.pixelSize: T.fontCaption
        font.features: ({ "tnum": 1 })
    }
}
