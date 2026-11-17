.pragma library

// The standard widget states (D-54) and the age text of a stale one. The host draws the placeholders from these.
const STALE_AFTER_MS = 60 * 60 * 1000;

// needsSetup, loading, error, stale or ready. busy: a request is in flight; failing: the last one failed.
function state(i) {
    if (i.needsSetup)
        return "needsSetup";
    if (!i.hasData)
        return i.failing && !i.busy ? "error" : "loading";
    return i.failing || i.now - i.updatedMs > STALE_AFTER_MS ? "stale" : "ready";
}

// { unit: "minute" | "hour" | "day", n } for "updated N ago", rounded down and at least 1.
function age(updatedMs, now) {
    const minutes = Math.max(1, Math.floor((now - updatedMs) / 60000));
    if (minutes < 60)
        return { "unit": "minute", "n": minutes };
    const hours = Math.floor(minutes / 60);
    return hours < 24 ? { "unit": "hour", "n": hours } : { "unit": "day", "n": Math.floor(hours / 24) };
}
