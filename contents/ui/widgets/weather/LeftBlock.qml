pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.." as Island
import "../../controlcenter" as CC
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast
import "../../weather" as Weather
import ".." as Widgets

// The 1x1 face of Weather (D-55), also the left block of the wider spans: place, condition glyph top right, the current
// temperature, and the detail line. Hovering for a moment peeks the other detail value (cross-fade, instant with reduced
// motion); leaving fades back. The dwell timer runs only while the pointer is over the block.
Item {
    id: block

    required property var base
    property bool peeking: false
    readonly property string main: block.base.settings.detail
    readonly property var primary: block.base.detailFor(block.main)
    readonly property var peek: block.base.detailFor(Forecast.other(block.main))

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered)
                dwell.restart();
            else {
                dwell.stop();
                block.peeking = false;
            }
        }
    }

    Timer {
        id: dwell

        interval: T.widgetPeekDwell
        onTriggered: block.peeking = true
    }

    Widgets.TileFace {
        anchors.fill: parent
        anchors.margins: T.widgetPadding
        labelInset: T.widgetGlyph + T.deckSpacing
        label: block.base.service ? block.base.service.locationName : ""
        hero: block.base.service && block.base.service.hasData ? Forecast.deg(block.base.service.temperatureC, block.base.fahrenheit) : ""

        Weather.WeatherIcon {
            anchors.top: parent.top
            anchors.right: parent.right
            width: T.widgetGlyph
            height: T.widgetGlyph
            code: block.base.service && block.base.service.hasData ? block.base.service.weatherCode : -1
            isDay: block.base.service ? block.base.service.isDay : true
        }

        DetailRow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            parts: block.primary
            shown: block.peeking ? 0 : 1
        }

        DetailRow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            parts: block.peek
            shown: block.peeking ? 1 : 0
        }
    }

    component DetailRow: RowLayout {
        id: row

        property var parts: ({ "head": "", "glyph": "", "tail": "" })
        property real shown: 1

        opacity: row.shown
        spacing: T.deckSpacing

        Behavior on shown {
            enabled: !block.base.reduceMotion

            NumberAnimation {
                duration: T.motionHover
                easing.type: T.easingStandard
            }
        }

        Island.PlasmaLabel {
            Layout.fillWidth: row.parts.glyph === ""
            Layout.maximumWidth: row.width
            text: row.parts.head
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        CC.ThemeGlyph {
            visible: row.parts.glyph !== ""
            Layout.preferredWidth: T.widgetSunGlyph
            Layout.preferredHeight: T.widgetSunGlyph
            names: row.parts.glyph === "sunrise" ? ["weather-sunrise-symbolic", "weather-sunrise", "weather-clear-symbolic"] : ["weather-sunset-symbolic", "weather-sunset", "weather-clear-night-symbolic"]
            color: T.textSecondary
        }

        Island.PlasmaLabel {
            visible: row.parts.glyph !== ""
            text: row.parts.tail
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            maximumLineCount: 1
        }
    }
}
