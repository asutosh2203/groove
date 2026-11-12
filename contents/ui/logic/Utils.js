.pragma library

// Small pure helpers shared by the coordinator and the views.

function hasVisualValue(value) {
    if (value === undefined || value === null)
        return false;
    return typeof value !== "string" || value.trim().length > 0;
}

function finiteNumber(value, fallbackValue) {
    const number = Number(value);
    return isFinite(number) ? number : fallbackValue;
}

function clampNumber(value, minimumValue, maximumValue) {
    const minimum = finiteNumber(minimumValue, 0);
    const maximum = Math.max(minimum, finiteNumber(maximumValue, minimum));
    return Math.max(minimum, Math.min(maximum, finiteNumber(value, minimum)));
}

function percentFromRatio(value, maximumValue) {
    const maximum = Math.max(1, finiteNumber(maximumValue, 1));
    return Math.round(clampNumber(value, 0, maximum) / maximum * 100);
}

function firstValidNumber(values, fallbackValue) {
    for (let i = 0; i < values.length; ++i) {
        const number = Number(values[i]);
        if (isFinite(number))
            return number;

    }
    return fallbackValue;
}

function formatByteSize(bytes) {
    let value = Math.max(0, finiteNumber(bytes, 0));
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }
    const decimals = unit === 0 || value >= 100 ? 0 : value >= 10 ? 1 : 2;
    return value.toFixed(decimals) + " " + units[unit];
}

function shellQuote(text) {
    return "'" + String(text || "").replace(/'/g, "'\"'\"'") + "'";
}
