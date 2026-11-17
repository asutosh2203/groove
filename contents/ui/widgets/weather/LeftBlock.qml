pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import "../../logic/WeatherForecast.js" as Forecast
import ".." as Widgets

// The 1x1 face of Weather (D-55), also the left block of the wider spans: place, condition glyph top right, the current
// temperature, and the detail line. Hovering for a moment peeks the other detail value (cross-fade, instant with reduced
// motion); leaving fades back. The dwell timer runs only while the pointer is over the block.
Item {
    id: block

    required property var base
    property bool peeking: false
    readonly property string main: block.base.settings.detail
    readonly property bool stale: block.base.staleText.length > 0
    // While stale, "updated N ago" takes the detail line's place (the three-line structure holds) and the peek is off.
    readonly property var primary: block.stale ? ({ "head": block.base.staleText, "glyph": "", "tail": "" }) : block.base.detailFor(block.main)
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
        label: block.base.service ? Forecast.cityName(block.base.service.locationName) : ""
        hero: block.base.service && block.base.service.hasData ? Forecast.deg(block.base.service.temperatureC, block.base.fahrenheit) : ""

        WeatherGlyph {
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
            shown: block.peeking && !block.stale ? 0 : 1
        }

        DetailRow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            parts: block.peek
            shown: block.peeking && !block.stale ? 1 : 0
        }
    }

    component DetailRow: RowLayout {
        id: row

        property var parts: ({ "head": "", "glyph": "", "tail": "" })
        property real shown: 1

        opacity: row.shown
        spacing: 0

        Behavior on shown {
            enabled: !block.base.reduceMotion

            NumberAnimation {
                duration: T.motionHover
                easing.type: T.easingStandard
            }
        }

        // One run: "Cloudy ·", a small gap, the glyph, a small gap, the time.
        Island.PlasmaLabel {
            Layout.fillWidth: row.parts.glyph === ""
            Layout.maximumWidth: row.width
            text: row.parts.head
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        SunGlyph {
            visible: row.parts.glyph !== ""
            Layout.leftMargin: row.parts.head.length > 0 ? T.deckSpacing : 0
            Layout.preferredWidth: T.widgetSunGlyph
            Layout.preferredHeight: T.widgetSunGlyph
            kind: row.parts.glyph
            color: T.textSecondary
        }

        Island.PlasmaLabel {
            visible: row.parts.glyph !== ""
            Layout.leftMargin: T.deckSpacing
            text: row.parts.tail
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            maximumLineCount: 1
        }

        Item {
            Layout.fillWidth: row.parts.glyph !== ""
        }
    }
}
