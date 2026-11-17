import QtQuick
import org.kde.plasma.plasmoid
import "../logic/WeatherCodes.js" as Codes
import "../logic/WeatherForecast.js" as Forecast
import "../logic/Subscribers.js" as Subs

// Open-Meteo current conditions and forecast for one location, in one request (no IP/GPS lookup). By default the location
// is the one chosen in the settings (the idle face's service); WeatherHub creates more for widget placements (D-55).
// The last good response is cached in the widget config (one cache for every location, D-55) and kept when a refresh fails.
// It fetches only while a view is subscribed (plus a grace period after the last leaves).
Item {
    id: service

    readonly property var cfg: Plasmoid.configuration
    // The settings' location unless a widget placement sets its own (then it does not follow the settings).
    property bool followsSettings: true
    property string locationName: String(cfg.weatherLocationName || "")
    property real latitude: Number(cfg.weatherLatitude)
    property real longitude: Number(cfg.weatherLongitude)
    readonly property bool configured: locationName.length > 0 && isFinite(latitude) && isFinite(longitude)
    readonly property bool fahrenheit: cfg.weatherUnit === "fahrenheit"

    property real temperatureC: NaN
    property int weatherCode: -1
    property bool isDay: true
    // The normalised forecast (WeatherForecast.parse) or null until a response carries one.
    property var forecast: null
    property double updatedMs: 0
    property bool failing: false
    readonly property bool hasData: configured && isFinite(temperatureC) && weatherCode >= 0
    readonly property var temperature: Codes.temperatureParts(hasData ? temperatureC : NaN, fahrenheit)
    readonly property string temperatureText: temperature.value + temperature.unit
    readonly property string forecastUrl: configured ? Codes.forecastUrl(latitude, longitude) : ""
    readonly property int refreshMs: 30 * 60 * 1000
    property bool busy: false
    property var subscribers: Subs.create()
    property bool active: false

    function syncActive() {
        active = Subs.isActive(subscribers, Date.now());
        if (!active)
            retryTimer.stop();
        else if (subscribers.count === 0)
            graceTimer.restart();
    }

    // A visible view calls these in pairs; the first subscriber triggers a refresh only if stale.
    function subscribe() {
        subscribers = Subs.add(subscribers);
        graceTimer.stop();
        syncActive();
        if (subscribers.count === 1)
            refreshIfStale();
    }

    function unsubscribe() {
        subscribers = Subs.remove(subscribers, Date.now());
        graceTimer.interval = Math.max(1, Subs.graceLeft(subscribers, Date.now()));
        syncActive();
    }

    function coordsMatch(a, b) {
        return Math.abs(Number(a) - Number(b)) < 0.0001;
    }

    function clearData() {
        temperatureC = NaN;
        weatherCode = -1;
        forecast = null;
        updatedMs = 0;
        failing = false;
    }

    function loadCache() {
        clearData();
        if (!configured)
            return ;
        const entry = Forecast.cacheRead(String(cfg.weatherForecastCache || ""), Forecast.locationKey(latitude, longitude));
        if (entry) {
            temperatureC = entry.current.t;
            weatherCode = entry.current.code;
            isDay = entry.current.isDay !== false;
            forecast = entry.forecast || null;
            updatedMs = entry.updatedMs;
            return ;
        }
        loadLegacyCache();
    }

    // The single-location cache from before the forecast, read once for the settings' location so the idle face is not blank.
    function loadLegacyCache() {
        try {
            const c = JSON.parse(cfg.weatherCacheJson || "{}");
            if (followsSettings && coordsMatch(c.lat, latitude) && coordsMatch(c.lon, longitude) && typeof c.temperatureC === "number" && typeof c.code === "number") {
                temperatureC = c.temperatureC;
                weatherCode = c.code;
                isDay = c.isDay !== false;
                updatedMs = Number(c.updatedMs) || 0;
            }
        } catch (e) {
            // Unreadable cache is ignored; the next fetch rewrites it.
        }
    }

    function saveCache() {
        const entry = { "updatedMs": updatedMs, "current": { "t": temperatureC, "code": weatherCode, "isDay": isDay }, "forecast": forecast ? Forecast.trim(forecast, updatedMs) : null };
        cfg.weatherForecastCache = Forecast.cacheWrite(String(cfg.weatherForecastCache || ""), Forecast.locationKey(latitude, longitude), entry);
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
                    forecast = Forecast.parse(json);
                    updatedMs = Date.now();
                    saveCache();
                    ok = true;
                }
            } catch (e) {
                ok = false;
            }
            done(ok);
        };
        request.ontimeout = () => done(false);
        request.onerror = () => done(false);
        request.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + Forecast.FORECAST_QUERY);
        request.send();
    }

    function refreshIfStale() {
        if (configured && Codes.isStale(hasData && forecast !== null, updatedMs, Date.now(), refreshMs))
            refresh();
    }

    Component.onCompleted: loadCache()

    Connections {
        target: Plasmoid.configuration

        function onWeatherLatitudeChanged() { if (service.followsSettings) service.relocate(); }
        function onWeatherLongitudeChanged() { if (service.followsSettings) service.relocate(); }
        function onWeatherLocationNameChanged() { if (service.followsSettings) service.relocate(); }
    }

    function doRelocate() {
        loadCache();
        busy = false;
        if (active)
            refresh();
    }

    // callLater with a function reference coalesces the three config change signals into one fetch.
    function relocate() {
        Qt.callLater(doRelocate);
    }

    Timer {
        interval: service.refreshMs
        repeat: true
        running: service.configured && service.active
        onTriggered: service.refresh()
    }

    Timer {
        id: graceTimer

        onTriggered: service.syncActive()
    }

    Timer {
        id: retryTimer

        interval: 10 * 60 * 1000
        onTriggered: service.refresh()
    }
}
