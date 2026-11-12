.pragma library
.import "TextUtils.js" as TextUtils
.import "Utils.js" as Utils

// How a job (a file copy, a download) reads, as pure functions. A job row carries `details` (an object with the
// job's own fields, may be absent) and plain model roles; the details win and the roles are the fallback. The
// service reads the roles and passes the values in. Translated text is left to the caller: titleText and appText may
// be empty, and detailsParts says which line applies, never what it is called in the user's language.

function titleText(details, summaryRole) {
    return TextUtils.cleanText(details && details.summary ? details.summary : summaryRole);
}

// The job's own text, else the application's name.
function text(details, bodyRole, applicationNameRole) {
    const body = TextUtils.cleanText(details && details.text ? details.text : bodyRole);
    if (body.length > 0)
        return body;
    return TextUtils.cleanText(details && details.applicationName ? details.applicationName : applicationNameRole);
}

function icon(details, applicationIconRole, desktopEntryRole) {
    const name = details && details.applicationIconName ? details.applicationIconName : applicationIconRole;
    if (Utils.hasVisualValue(name))
        return name;
    const entry = TextUtils.cleanText(details && details.desktopEntry ? details.desktopEntry : desktopEntryRole);
    return entry.length > 0 ? entry : "folder-download";
}

function state(details, stateRole) {
    if (details && details.state !== undefined)
        return details.state;
    return stateRole;
}

// 0..100, or -1 when the job reports no percentage.
function percentage(details, percentageRole) {
    const value = details && details.percentage !== undefined ? details.percentage : percentageRole;
    return Math.max(-1, Math.min(100, Math.round(Utils.finiteNumber(value, -1))));
}

function suspendable(details, suspendableRole) {
    return details && details.suspendable !== undefined ? details.suspendable : Boolean(suspendableRole);
}

function killable(details, killableRole) {
    return details && details.killable !== undefined ? details.killable : Boolean(killableRole);
}

// Which detail line to show: { kind: "none" | "paused" | "speed" | "progress" | "app", ... }. A suspended job always
// reads as paused; otherwise the speed wins, then bytes done of total, then the application's name.
function detailsParts(details, suspended) {
    if (!details)
        return { "kind": suspended ? "paused" : "none" };
    if (suspended)
        return { "kind": "paused" };
    if (Utils.finiteNumber(details.speed, 0) > 0)
        return { "kind": "speed", "speed": Utils.finiteNumber(details.speed, 0) };
    const processed = Utils.finiteNumber(details.processedBytes, 0);
    const total = Utils.finiteNumber(details.totalBytes, 0);
    if (total > 0)
        return { "kind": "progress", "processed": processed, "total": total };
    return { "kind": "app", "text": TextUtils.cleanText(details.applicationName || "") };
}
