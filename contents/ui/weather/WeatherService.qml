import QtQuick
import org.kde.plasma.plasmoid
import "WeatherCodes.js" as Codes

// Open-Meteo current conditions for the location chosen in the settings (no IP/GPS lookup).
// The last good response is cached in the widget config and kept when a refresh fails.
Item {
    id: service

    readonly property var cfg: Plasmoid.configuration
    readonly property string locationName: String(cfg.weatherLocationName || "")
    readonly property real latitude: Number(cfg.weatherLatitude)
    readonly property real longitude: Number(cfg.weatherLongitude)
    readonly property bool configured: locationName.length > 0 && isFinite(latitude) && isFinite(longitude)
    readonly property bool fahrenheit: cfg.weatherUnit === "fahrenheit"

    property real temperatureC: NaN
    property int weatherCode: -1
    property bool isDay: true
    property double updatedMs: 0
    property bool failing: false
    readonly property bool hasData: configured && isFinite(temperatureC) && weatherCode >= 0
    readonly property var temperature: Codes.temperatureParts(hasData ? temperatureC : NaN, fahrenheit)
    readonly property string temperatureText: temperature.value + temperature.unit
    readonly property string forecastUrl: configured ? Codes.forecastUrl(latitude, longitude) : ""
    readonly property int refreshMs: 30 * 60 * 1000
    property bool busy: false

    function coordsMatch(a, b) {
        return Math.abs(Number(a) - Number(b)) < 0.0001;
    }

    function clearData() {
        temperatureC = NaN;
        weatherCode = -1;
        updatedMs = 0;
        failing = false;
    }

    function loadCache() {
        clearData();
        if (!configured)
            return ;
        try {
            const c = JSON.parse(cfg.weatherCacheJson || "{}");
            if (coordsMatch(c.lat, latitude) && coordsMatch(c.lon, longitude) && typeof c.temperatureC === "number" && typeof c.code === "number") {
                temperatureC = c.temperatureC;
                weatherCode = c.code;
                isDay = c.isDay !== false;
                updatedMs = Number(c.updatedMs) || 0;
            }
        } catch (e) {
            // Unreadable cache is ignored; the next fetch rewrites it.
        }
    }

    function refresh() {
        if (!configured || busy)
            return ;
        busy = true;
        const lat = latitude.toFixed(4);
        const lon = longitude.toFixed(4);
        const request = new XMLHttpRequest();
        request.timeout = 15000;
        const done = ok => {
            busy = false;
            failing = !ok;
            if (ok)
                retryTimer.stop();
            else
                retryTimer.restart();
        };
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE)
                return ;
            let ok = false;
            try {
                const json = request.status === 200 ? JSON.parse(request.responseText) : null;
                // Ignore answers for a location that was changed while the request was in flight.
                if (Codes.validCurrent(json) && lat === latitude.toFixed(4) && lon === longitude.toFixed(4)) {
                    temperatureC = json.current.temperature_2m;
                    weatherCode = json.current.weather_code;
                    isDay = json.current.is_day !== 0;
                    updatedMs = Date.now();
                    cfg.weatherCacheJson = JSON.stringify({ "lat": latitude, "lon": longitude, "temperatureC": temperatureC, "code": weatherCode, "isDay": isDay, "updatedMs": updatedMs });
                    ok = true;
                }
            } catch (e) {
                ok = false;
            }
            done(ok);
        };
        request.ontimeout = () => done(false);
        request.onerror = () => done(false);
        request.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + "&current=temperature_2m,weather_code,is_day&timezone=auto");
        request.send();
    }

    function refreshIfStale() {
        if (configured && (!hasData || Date.now() - updatedMs > refreshMs - 60000))
            refresh();
    }

    Component.onCompleted: {
        loadCache();
        refreshIfStale();
    }

    Connections {
        target: Plasmoid.configuration

        function onWeatherLatitudeChanged() { service.relocate(); }
        function onWeatherLongitudeChanged() { service.relocate(); }
        function onWeatherLocationNameChanged() { service.relocate(); }
    }

    function doRelocate() {
        loadCache();
        busy = false;
        refresh();
    }

    // callLater with a function reference coalesces the three config change signals into one fetch.
    function relocate() {
        Qt.callLater(doRelocate);
    }

    Timer {
        interval: service.refreshMs
        repeat: true
        running: service.configured
        onTriggered: service.refresh()
    }

    Timer {
        id: retryTimer

        interval: 10 * 60 * 1000
        onTriggered: service.refresh()
    }
}
