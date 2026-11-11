import QtQuick
import QtQuick.Controls as QQC2
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

        PlasmaLabel {
            id: timeLabel

            anchors.centerIn: parent
            text: Qt.formatTime(idle.now, Qt.locale(), Locale.ShortFormat)
            color: timeHover.hovered ? "#ffffff" : "#e9e9ef"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        HoverHandler {
            id: timeHover
        }

        QQC2.ToolTip.visible: timeHover.hovered && !idle.app.islandOpen
        QQC2.ToolTip.delay: 600
        QQC2.ToolTip.text: Qt.formatDate(idle.now, Qt.locale(), Locale.LongFormat) + "\n" + (idle.app.calendarAppId().length > 0 ? i18n("Click to open calendar") : i18n("No calendar application found. Choose one in the widget settings."))
    }

    Item {
        id: weatherArea

        anchors.right: parent.right
        anchors.rightMargin: idle.sideMargin - 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: weatherRow.implicitWidth + 12

        Row {
            id: weatherRow

            anchors.centerIn: parent
            spacing: 4

            WeatherIcon {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                code: idle.weather && idle.weather.hasData ? idle.weather.weatherCode : -1
                isDay: idle.weather ? idle.weather.isDay : true
                placeholder: !idle.weather || !idle.weather.hasData
                running: idle.animate && idle.visible
            }

            PlasmaLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: idle.weather ? idle.weather.temperatureText : "--°"
                color: weatherHover.hovered ? "#ffffff" : "#e9e9ef"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        HoverHandler {
            id: weatherHover
        }

        QQC2.ToolTip.visible: weatherHover.hovered && !idle.app.islandOpen
        QQC2.ToolTip.delay: 600
        QQC2.ToolTip.text: !idle.weather || !idle.weather.configured ? i18n("No weather location set. Choose one in the widget settings.") : (idle.weather.hasData ? i18n("Updated %1", Qt.formatTime(new Date(idle.weather.updatedMs), Qt.locale(), Locale.ShortFormat)) + (idle.weather.failing ? "\n" + i18n("Offline, showing last known weather") : "") : i18n("Weather unavailable")) + (idle.weather && idle.weather.configured ? "\n" + i18n("Click to open the forecast") : "")
    }
}
