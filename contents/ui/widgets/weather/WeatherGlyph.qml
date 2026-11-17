pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../../controlcenter" as CC
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherCodes.js" as Codes
import "../../weather" as Weather

// A condition glyph in the island's colour (D-45, D-55): the theme's weather-*-symbolic icon when it has one, else the
// bundled weather icon drawn as a white silhouette (same shapes, one colour). The mask layer exists only while it shows.
Item {
    id: glyph

    property int code: -1
    property bool isDay: true
    property color color: T.textPrimary

    CC.ThemeGlyph {
        id: themed

        anchors.fill: parent
        visible: themed.anyValid
        names: Codes.symbolicNames(glyph.code, glyph.isDay)
        color: glyph.color
    }

    Item {
        anchors.fill: parent
        visible: !themed.anyValid
        layer.enabled: visible
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: glyph.color
        }

        Weather.WeatherIcon {
            anchors.fill: parent
            code: glyph.code
            isDay: glyph.isDay
        }
    }
}
