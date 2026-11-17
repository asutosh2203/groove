.pragma library

// Clock and World Clock text (D-55). Pure functions of an instant (ms since the epoch) and a UTC offset in seconds. Plasma's
// Clock supplies the offset, so DST is Plasma's; a wall time here is the instant shifted by the offset and read with getUTC*.

// "UTC+05:30", "UTC-5", "UTC" -> seconds; NaN when unreadable.
function parseOffset(text) {
    const m = /^(?:UTC|GMT)?(?:([+\-−])(\d{1,2})(?::?(\d{2}))?)?$/.exec(String(text).trim());
    if (!m)
        return NaN;
    if (m[1] === undefined)
        return 0;
    const sign = m[1] === "+" ? 1 : -1;
    return sign * ((Number(m[2]) * 60 + Number(m[3] || 0)) * 60);
}

function wall(ms, offsetSec) {
    const d = new Date(ms + offsetSec * 1000);
    return { "y": d.getUTCFullYear(), "mo": d.getUTCMonth(), "d": d.getUTCDate(), "h": d.getUTCHours(), "mi": d.getUTCMinutes(), "dow": d.getUTCDay() };
}

function pad(n) {
    return n < 10 ? "0" + n : String(n);
}

// A locale short time format such as "h:mm AP" or "HH:mm": 12-hour when it has an AM/PM marker outside quotes.
function is24Hour(format) {
    return !/[aA]/.test(String(format).replace(/'[^']*'/g, ""));
}

// mode: "24h", "12h" or "locale" (then locale24 decides). am and pm come from the locale.
function timeText(ms, offsetSec, mode, locale24, am, pm) {
    const w = wall(ms, offsetSec);
    if (mode === "24h" || (mode !== "12h" && locale24))
        return pad(w.h) + ":" + pad(w.mi);
    const h = w.h % 12 === 0 ? 12 : w.h % 12;
    return h + ":" + pad(w.mi) + " " + (w.h < 12 ? am : pm);
}

// "Tue 17 Nov". days: seven short names from Sunday, months: twelve short names.
function dateText(ms, offsetSec, days, months) {
    const w = wall(ms, offsetSec);
    return days[w.dow] + " " + w.d + " " + months[w.mo];
}

// "Europe/Berlin" -> "Berlin", "America/Argentina/Buenos_Aires" -> "Buenos Aires"; "" for an unusable id.
function cityName(zoneId) {
    const parts = String(zoneId).split("/");
    return parts[parts.length - 1].replace(/_/g, " ");
}

function dayNumber(ms, offsetSec) {
    return Math.floor((ms + offsetSec * 1000) / 86400000);
}

// -1 yesterday, 0 today, 1 tomorrow: that city's date against the local date.
function dayRelation(ms, offsetSec, localOffsetSec) {
    return Math.sign(dayNumber(ms, offsetSec) - dayNumber(ms, localOffsetSec));
}

// The city's offset from local time: "+5:30", "−9:30", "+0:00".
function offsetText(offsetSec, localOffsetSec) {
    const minutes = Math.round((offsetSec - localOffsetSec) / 60);
    const abs = Math.abs(minutes);
    return (minutes < 0 ? "−" : "+") + Math.floor(abs / 60) + ":" + pad(abs % 60);
}
