.pragma library
.import "TextUtils.js" as TextUtils
.import "Utils.js" as Utils

// How a notification row reads, as pure functions of the values its model roles hold. The service reads the roles;
// these decide what to show. `urgency` values are KDE's enum (Low = 1, Normal = 2, Critical = 4), not the D-Bus byte.

function appName(applicationName, desktopEntry, fallback) {
    const name = TextUtils.cleanText(applicationName);
    if (name.length > 0)
        return name;

    const entry = TextUtils.cleanText(desktopEntry);
    return entry.length > 0 ? entry : fallback;
}

function title(summary, appNameText) {
    const text = TextUtils.cleanText(summary);
    return text.length > 0 ? text : appNameText;
}

function appIcon(applicationIcon, desktopEntry) {
    if (Utils.hasVisualValue(applicationIcon))
        return applicationIcon;

    const entry = TextUtils.cleanText(desktopEntry);
    return entry.length > 0 ? entry : "notifications";
}

function mainIcon(icon, appIconName) {
    return Utils.hasVisualValue(icon) ? icon : appIconName;
}

// The notification's own image, else the first attached URL that is an image file, else null.
function mainImage(image, urls) {
    if (Utils.hasVisualValue(image))
        return image;

    if (!urls || urls.length === undefined)
        return null;
    for (let i = 0; i < urls.length; ++i) {
        const candidate = String(urls[i] || "");
        const path = candidate.split(/[?#]/)[0].toLowerCase();
        if (/\.(avif|bmp|gif|heic|heif|jpe?g|png|svgz?|webp)$/.test(path))
            return urls[i];
    }
    return null;
}

// Used by activity priority, which compares against a loose scale (>= 2 is urgent), so unknown values read as Low.
function urgency(raw) {
    return Utils.finiteNumber(raw, 1);
}

function accent(urgencyValue) {
    if (urgencyValue >= 2)
        return "#ff453a";
    if (urgencyValue <= 0)
        return "#8f9099";
    return "#ff9f0a";
}

// Colour of the small urgency dot in the expanded notification: grey / green / red for low / normal / critical.
// Anything unknown is shown as Normal (green), never as Critical. `levels` is { low, critical }, the enum values.
function urgencyColor(raw, levels) {
    switch (raw) {
    case levels.low:
        return "#6c6e78";
    case levels.critical:
        return "#E66A65";
    default:
        return "#3ac255";
    }
}

// Creation time in ms since the epoch from a Date or a number, 0 when unknown. Display only.
function createdMs(created) {
    const t = created && created.getTime ? created.getTime() : Number(created);
    return isFinite(t) && t > 0 ? t : 0;
}

// The model only exposes a limited window of history, so older entries can slide in as rows are removed. Only recently
// created notifications count as arrivals, and none while Clear All is running.
function isFresh(created, nowMs, clearing) {
    if (clearing)
        return false;
    if (!created)
        return true;
    const t = created.getTime ? created.getTime() : Number(created);
    return !isFinite(t) || Math.abs(nowMs - t) < 15000;
}
