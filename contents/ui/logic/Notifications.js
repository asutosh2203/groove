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

// --- finding rows ---------------------------------------------------------------------------------------------------
// The service reads the model once into plain arrays (`types`: the TypeRole value of each row; `items`: small objects),
// and these decide which rows are meant. Row numbers are model rows; -1 means none.

function firstRowOfType(types, type) {
    for (let i = 0; i < types.length; ++i) {
        if (types[i] === type)
            return i;
    }
    return -1;
}

// The rows of a type in model order (newest first); limit 0 means all.
function rowsOfType(types, type, limit) {
    const out = [];
    const maxRows = Math.max(0, Math.round(Utils.finiteNumber(limit, 0)));
    for (let i = 0; i < types.length; ++i) {
        if (types[i] !== type)
            continue;

        out.push(i);
        if (maxRows > 0 && out.length >= maxRows)
            break;

    }
    return out;
}

function overflow(count, limit) {
    return Math.max(0, count - Math.max(0, Math.round(Utils.finiteNumber(limit, 0))));
}

// The notification row with this id; items: [{ type, id }]. Ids are compared as text, jobs never match.
function rowOfId(items, id, noticeType) {
    if (id === null || id === undefined)
        return -1;
    const wanted = String(id);
    for (let i = 0; i < items.length; ++i) {
        if (items[i].type !== noticeType)
            continue;
        if (String(items[i].id) === wanted)
            return i;
    }
    return -1;
}

// The row being presented, else the newest notification, else -1.
function latestRow(trackedRow, noticeRows) {
    if (trackedRow >= 0)
        return trackedRow;
    return noticeRows.length > 0 ? noticeRows[0] : -1;
}

// Which rows Clear All closes, last row first so earlier numbers stay valid; items: [{ type, closable }].
function closableRows(items, noticeType) {
    const out = [];
    for (let i = items.length - 1; i >= 0; --i) {
        if (items[i].type === noticeType && items[i].closable)
            out.push(i);
    }
    return out;
}

// --- opening --------------------------------------------------------------------------------------------------------

// The facts NotificationOpen.resolve decides on, from the row's roles. info: the desktop entry's { display } or undefined.
function openInput(desktopEntry, expired, hasDefaultAction, urls, info) {
    return {
        "expired": expired === true,
        "hasDefaultAction": hasDefaultAction === true,
        "urls": urls,
        "desktopEntry": desktopEntry,
        "desktopEntryLaunchable": info !== undefined && info.display === true
    };
}

// What a click does for a resolved target ({ kind: "action" | "url" | "app" | "none" }): invoke the live action, or open
// the URL / launch the app and then close the notification when it can be closed.
function openPlan(kind, closable) {
    return {
        "invokeAction": kind === "action",
        "openUrl": kind === "url",
        "launchApp": kind === "app",
        "close": kind !== "action" && kind !== "none" && closable === true
    };
}
