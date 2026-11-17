.pragma library

// Open-Meteo geocoding, shared by the settings page and the preset editor: the request URL and the result rows. The
// user searches and explicitly picks a result (no GPS or IP guessing).
function url(query, localeName) {
    return "https://geocoding-api.open-meteo.com/v1/search?count=8&format=json&language=" + encodeURIComponent(String(localeName).split("_")[0]) + "&name=" + encodeURIComponent(query.trim());
}

function validQuery(query) {
    return query.trim().length >= 2;
}

// Rows from a response body: [{ text, name, lat, lon }], or null when the body is not a geocoding response.
function parse(body) {
    let rows;
    try {
        rows = JSON.parse(body).results || [];
    } catch (e) {
        return null;
    }
    if (!Array.isArray(rows))
        return null;
    return rows.filter(r => r && typeof r.name === "string" && typeof r.latitude === "number" && typeof r.longitude === "number").map(r => ({
        "text": [r.name, r.admin1, r.country].filter(x => x && x.length > 0).join(", "),
        "name": r.name,
        "lat": r.latitude,
        "lon": r.longitude
    }));
}
