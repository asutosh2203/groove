.pragma library

// Weather widget data (D-55): the one Open-Meteo response normalised, and the pure decisions on it (the day columns, the
// next sun event, the hourly strip, the detail line). Times are epoch ms; a location's wall time is ms + offset (seconds).

const FORECAST_QUERY = "&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&hourly=temperature_2m,weather_code,is_day&forecast_days=6&timezone=auto";
const HOURS_KEPT = 48;

// "2026-11-17T18:00" in the location's zone -> epoch ms.
function localMs(text, offsetSec) {
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?/.exec(String(text));
    if (!m)
        return NaN;
    return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4] || 0), Number(m[5] || 0)) - offsetSec * 1000;
}

function num(v) {
    return typeof v === "number" && isFinite(v) ? v : NaN;
}

// The forecast part of a response: { offset, daily: [{ date, dow, code, max, min, sunrise, sunset }], hourly: [{ ms, t, code, isDay }] }
// or null when the response carries none. Rows with a missing value are left out.
function parse(json) {
    const d = json && json.daily;
    const h = json && json.hourly;
    const offset = Number(json && json.utc_offset_seconds);
    if (!d || !h || !Array.isArray(d.time) || !Array.isArray(h.time) || !isFinite(offset))
        return null;
    const daily = [];
    for (let i = 0; i < d.time.length; ++i) {
        const date = String(d.time[i]);
        const row = { "date": date, "dow": new Date(localMs(date, 0)).getUTCDay(), "code": num(d.weather_code && d.weather_code[i]), "max": num(d.temperature_2m_max && d.temperature_2m_max[i]), "min": num(d.temperature_2m_min && d.temperature_2m_min[i]), "sunrise": localMs(d.sunrise && d.sunrise[i], offset), "sunset": localMs(d.sunset && d.sunset[i], offset) };
        if (isFinite(row.dow) && isFinite(row.max) && isFinite(row.min) && isFinite(row.code))
            daily.push(row);
    }
    const hourly = [];
    for (let i = 0; i < h.time.length; ++i) {
        const row = { "ms": localMs(h.time[i], offset), "t": num(h.temperature_2m && h.temperature_2m[i]), "code": num(h.weather_code && h.weather_code[i]), "isDay": !!(h.is_day && h.is_day[i]) };
        if (isFinite(row.ms) && isFinite(row.t) && isFinite(row.code))
            hourly.push(row);
    }
    return { "offset": offset, "daily": daily, "hourly": hourly };
}

// What the cache keeps: the hours from one hour ago on, at most HOURS_KEPT of them.
function trim(fc, nowMs) {
    return { "offset": fc.offset, "daily": fc.daily, "hourly": fc.hourly.filter(r => r.ms >= nowMs - 3600000).slice(0, HOURS_KEPT) };
}

function dateOf(ms, offsetSec) {
    const d = new Date(ms + offsetSec * 1000);
    const p = n => (n < 10 ? "0" : "") + n;
    return d.getUTCFullYear() + "-" + p(d.getUTCMonth() + 1) + "-" + p(d.getUTCDate());
}

// Today's row, or null.
function today(fc, nowMs) {
    const date = dateOf(nowMs, fc.offset);
    return fc.daily.find(r => r.date === date) || null;
}

// The next `count` day columns starting today: { dow, code, max, min, isToday }.
function days(fc, nowMs, count) {
    const date = dateOf(nowMs, fc.offset);
    return fc.daily.filter(r => r.date >= date).slice(0, count).map(r => ({ "dow": r.dow, "code": r.code, "max": r.max, "min": r.min, "isToday": r.date === date }));
}

// The next sunrise or sunset after now: { kind: "sunrise" | "sunset", ms } or null. Sunset in the day, sunrise at night.
function nextSun(fc, nowMs) {
    let best = null;
    for (const r of fc.daily) {
        for (const kind of ["sunrise", "sunset"]) {
            const ms = r[kind];
            if (isFinite(ms) && ms > nowMs && (best === null || ms < best.ms))
                best = { "kind": kind, "ms": ms };
        }
    }
    return best;
}

// The hourly strip, `count` columns wide: "Now" first, then the following hours, with the next sun event as its own column
// at its time (only if it falls before the last hour shown). Columns: { kind: "now" | "hour" | "sun", ms, t, code, isDay, sun }.
function strip(fc, nowMs, current, count) {
    const out = [{ "kind": "now", "ms": nowMs, "t": current.t, "code": current.code, "isDay": current.isDay, "sun": "" }];
    const hours = fc.hourly.filter(r => r.ms > nowMs).slice(0, Math.max(0, count - 1)).map(r => ({ "kind": "hour", "ms": r.ms, "t": r.t, "code": r.code, "isDay": r.isDay, "sun": "" }));
    const sun = nextSun(fc, nowMs);
    if (sun !== null && hours.length > 0 && sun.ms <= hours[hours.length - 1].ms) {
        const at = hours.findIndex(r => r.ms > sun.ms);
        hours.splice(at < 0 ? hours.length : at, 0, { "kind": "sun", "ms": sun.ms, "t": NaN, "code": -1, "isDay": sun.kind === "sunrise", "sun": sun.kind });
    }
    return out.concat(hours).slice(0, count);
}

function deg(celsius, fahrenheit) {
    return Math.round(fahrenheit ? celsius * 9 / 5 + 32 : celsius) + "°";
}

// The 1x1 detail line as { head, glyph, tail }: "Cloudy · 27° / 18°", or "Cloudy · " + a sun glyph + "17:58".
// setting: "highlow" or "sun". o: { condition, today: { max, min } | null, sun: { kind, ms } | null, fahrenheit, offset }.
// hm(ms, offset) formats a time of day.
function detail(setting, o, hm) {
    const lead = o.condition.length > 0 ? o.condition + " · " : "";
    if (setting === "sun" && o.sun)
        return { "head": lead, "glyph": o.sun.kind, "tail": hm(o.sun.ms, o.offset) };
    if (setting === "highlow" && o.today)
        return { "head": lead + deg(o.today.max, o.fahrenheit) + " / " + deg(o.today.min, o.fahrenheit), "glyph": "", "tail": "" };
    return { "head": o.condition, "glyph": "", "tail": "" };
}

// The value the hover peek swaps in.
function other(setting) {
    return setting === "sun" ? "highlow" : "sun";
}
