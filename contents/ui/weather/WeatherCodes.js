.pragma library

// Open-Meteo WMO weather code (+ day/night) -> icon key in WeatherManifest.js.
function iconKey(code, isDay) {
    const day = isDay !== false && isDay !== 0;
    const c = Number(code);
    if (c === 0 || c === 1)
        return day ? "clear-day" : "clear-night";
    if (c === 2)
        return day ? "partly-cloudy-day" : "partly-cloudy-night";
    if (c === 3)
        return "overcast";
    if (c === 45 || c === 48)
        return "fog";
    if (c === 51 || c === 53 || c === 55)
        return "drizzle";
    if (c === 56 || c === 57 || c === 66 || c === 67)
        return "sleet";
    if (c === 61 || c === 63 || c === 65)
        return "rain";
    if (c === 71 || c === 73 || c === 75 || c === 77)
        return "snow";
    if (c === 80 || c === 81 || c === 82)
        return day ? "partly-cloudy-day-rain" : "partly-cloudy-night-rain";
    if (c === 85 || c === 86)
        return day ? "partly-cloudy-day-snow" : "partly-cloudy-night-snow";
    if (c === 95 || c === 96 || c === 99)
        return "thunderstorms-rain";
    return "not-available";
}

function displayTemperature(celsius, fahrenheit) {
    if (typeof celsius !== "number" || !isFinite(celsius))
        return "--°";
    return Math.round(fahrenheit ? celsius * 9 / 5 + 32 : celsius) + "°";
}

// Human-readable forecast page for a coordinate (yr.no accepts "lat,lon").
function forecastUrl(lat, lon) {
    return "https://www.yr.no/en/forecast/daily-table/" + Number(lat).toFixed(4) + "," + Number(lon).toFixed(4);
}

function validCurrent(json) {
    const cur = json && json.current;
    return !!cur && typeof cur.temperature_2m === "number" && isFinite(cur.temperature_2m) && typeof cur.weather_code === "number";
}
