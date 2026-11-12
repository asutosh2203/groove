import QtQuick
import ".."

// Permanent idle face of the shell: local time on the left, weather on the right.
// Hit testing for single clicks is done by the island's MouseArea (see targetAt).
Item {
    id: idle

    property var app: null
    property bool animate: false
    property real sideMargin: 14
    readonly property var weather: app ? app.weather : null
    property date now: new Date()
    property bool primary: true
    // The panel's own tooltip is reused (via the app's idleHover* properties) so it never fights a second tooltip window.
    readonly property string hoverTitle: timeHover.hovered ? i18n("Open Calendar") : weatherHover.hovered ? (weather && weather.configured ? i18n("Open Weather Forecast") : i18n("Set Weather Location")) : ""
    // Rich-text tooltip: low-emphasis lines are small and muted.
    function tertiary(text) {
        return "<small><font color='#7f8490'>" + text + "</font></small>";
    }

    readonly property string hoverText: timeHover.hovered ? Qt.formatDate(idle.now, Qt.locale(), Locale.LongFormat) + (app && app.launcher.calendarAppId().length > 0 ? "" : "<br/>" + tertiary(i18n("No calendar application found. Choose one in the widget settings."))) : weatherHover.hovered ? (!weather || !weather.configured ? i18n("Choose a location in the widget settings.") : weather.hasData ? (conditionText(weather.weatherCode, weather.isDay).length > 0 ? conditionText(weather.weatherCode, weather.isDay) + "<br/>" : "") + tertiary(i18n("Updated %1", Qt.formatTime(new Date(weather.updatedMs), Qt.locale(), Locale.ShortFormat)) + (weather.failing ? " · " + i18n("offline, showing last known weather") : "")) : i18n("Weather unavailable")) : ""

    Binding {
        target: idle.app
        property: "idleHoverTitle"
        value: idle.hoverTitle
        when: idle.app !== null && idle.primary
    }

    Binding {
        target: idle.app
        property: "idleHoverText"
        value: idle.hoverText
        when: idle.app !== null && idle.primary
    }

    // Plain-language condition for the tooltip (WMO code groups from Open-Meteo).
    function conditionText(code, day) {
        const c = Number(code);
        if (c === 0)
            return day ? i18n("Sunny") : i18n("Clear sky");
        if (c === 1)
            return day ? i18n("Mostly sunny") : i18n("Mostly clear");
        if (c === 2)
            return i18n("Partly cloudy");
        if (c === 3)
            return i18n("Overcast");
        if (c === 45 || c === 48)
            return i18n("Fog");
        if (c === 51 || c === 53 || c === 55)
            return i18n("Drizzle");
        if (c === 56 || c === 57)
            return i18n("Freezing drizzle");
        if (c === 61 || c === 63 || c === 65)
            return i18n("Rain");
        if (c === 66 || c === 67)
            return i18n("Freezing rain");
        if (c === 71 || c === 73 || c === 75 || c === 77)
            return i18n("Snow");
        if (c === 80 || c === 81 || c === 82)
            return i18n("Rain showers");
        if (c === 85 || c === 86)
            return i18n("Snow showers");
        if (c === 95 || c === 96 || c === 99)
            return i18n("Thunderstorm");
        return "";
    }

    function targetAt(x, y) {
        if (timeArea.contains(timeArea.mapFromItem(idle, x, y)))
            return "time";
        if (weatherArea.contains(weatherArea.mapFromItem(idle, x, y)))
            return "weather";
        return "";
    }

    // One tick per minute, aligned to the minute boundary.
    Timer {
        id: minuteTimer

        interval: 60000 - Date.now() % 60000 + 50
        running: idle.visible
        repeat: false
        onTriggered: {
            idle.now = new Date();
            interval = 60000 - Date.now() % 60000 + 50;
            restart();
        }
    }
    onVisibleChanged: {
        if (visible) {
            now = new Date();
            minuteTimer.interval = 60000 - Date.now() % 60000 + 50;
        }
    }

    Item {
        id: timeArea

        anchors.left: parent.left
        anchors.leftMargin: idle.sideMargin - 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: timeLabel.implicitWidth + 12

        // Both text groups use the same baseline: digits are ~10px tall, so centre them on the mid-line.
        Item {
            id: timeBase

            y: Math.round(parent.height / 2 + 5.5)
        }

        PlasmaLabel {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.baseline: timeBase.top
            text: Qt.formatTime(idle.now, Qt.locale(), Locale.ShortFormat)
            color: timeHover.hovered ? "#ffffff" : "#e1e2e8"
            font.pixelSize: 16
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }

        HoverHandler {
            id: timeHover

            cursorShape: Qt.PointingHandCursor
        }

    }

    Item {
        id: weatherArea

        anchors.right: parent.right
        anchors.rightMargin: idle.sideMargin - 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: tempLabel.implicitWidth + 29 + 12

        Item {
            id: tempBase

            y: Math.round(parent.height / 2 + 5.5)
        }

        // Icon and temperature read as one group, sharing the time's baseline.
        PlasmaLabel {
            id: tempLabel

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.baseline: tempBase.top
            textFormat: Text.RichText
            text: idle.weather ? "<span style='color:" + (weatherHover.hovered ? "#ffffff" : "#e1e2e8") + "'>" + idle.weather.temperature.value + "\u2009</span><span style='font-size:10px; color:#9a9ca6'>" + idle.weather.temperature.unit + "</span>" : "--\u2009°C"
            color: "#ffffff"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        WeatherIcon {
            width: 26
            height: 26
            opacity: 1
            anchors.right: tempLabel.left
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            code: idle.weather && idle.weather.hasData ? idle.weather.weatherCode : -1
            isDay: idle.weather ? idle.weather.isDay : true
            placeholder: !idle.weather || !idle.weather.hasData
            running: idle.animate && idle.visible
            clock: idle.app ? idle.app.decorClock : null
        }

        HoverHandler {
            id: weatherHover

            cursorShape: Qt.PointingHandCursor
        }

    }
}
