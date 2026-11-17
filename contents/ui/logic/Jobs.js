.pragma library
.import "TextUtils.js" as TextUtils
.import "Utils.js" as Utils
.import "LiveGlyphs.js" as LiveGlyphs

// How a job (a file copy, a download) reads, as pure functions. A job row carries `details` (an object with the
// job's own fields, may be absent) and plain model roles; the details win and the roles are the fallback. The
// service reads the roles and passes the values in. Translated text is left to the caller: titleText and appText may
// be empty, and meta says which line applies, never what it is called in the user's language.

// The first of these values that reads as a non-empty string. Properties read from the notification model can be URL objects,
// which are truthy even when empty, so `a || b` would pick an empty destUrl over a filled description value.
function firstText(values) {
    for (const value of values) {
        const text = value === undefined || value === null ? "" : String(value);
        if (TextUtils.cleanText(text).length > 0)
            return text;
    }
    return "";
}

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

// What the job is doing: "copy" | "move" | "download" | "upload" | "delete" | "generic" (D-26: identifiers and URL schemes,
// never translated text). KIO reports its application's icon rather than a job icon, so the icon name only counts when it
// names an operation; otherwise the job's source (value 1) and destination (value 2 or destUrl) decide.
function kind(details, iconName) {
    const id = typeof iconName === "string" ? iconName.toLowerCase() : "";
    const byIcon = [["copy", "copy"], ["delete", "delete"], ["trash", "delete"], ["move", "move"], ["upload", "upload"], ["download", "download"]];
    for (const [key, k] of byIcon) {
        if (id.indexOf(key) >= 0)
            return k;
    }
    if (!details)
        return "generic";
    const src = TextUtils.cleanText(details.descriptionValue1 || "");
    const dst = TextUtils.cleanText(firstText([details.destUrl, details.descriptionValue2]));
    const remote = url => /^(https?|ftps?|sftp|smb|fish|webdav|webdavs|mtp|gdrive|nfs):/i.test(url);
    if (/^trash:/i.test(dst))
        return "delete";
    // Browsers report a remote source and no destination at all.
    if (remote(src) && dst.length === 0)
        return "download";
    if (src.length > 0 && dst.length > 0) {
        if (remote(src) && !remote(dst))
            return "download";
        if (!remote(src) && remote(dst))
            return "upload";
        return "copy";
    }
    if (dst.length === 0 && (Utils.finiteNumber(details.totalItems, 0) > 0 || Utils.finiteNumber(details.totalFiles, 0) > 0) && src.length > 0)
        return "delete";
    return "generic";
}

// The symbolic glyph names to try, in order, for a job (LiveGlyphs.js holds the chains).
function glyphNames(details, iconName) {
    return LiveGlyphs.chain(kind(details, iconName));
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

// The meta line: { kind: "none" | "paused" | "speed", speed, remaining }. A suspended job always reads as paused.
// `remaining` is whole seconds, or -1 unless both the total size and the speed are known.
function meta(details, suspended) {
    if (suspended)
        return { "kind": "paused" };
    const speed = details ? Utils.finiteNumber(details.speed, 0) : 0;
    if (speed <= 0)
        return { "kind": "none" };
    const total = Utils.finiteNumber(details.totalBytes, 0);
    const left = total - Utils.finiteNumber(details.processedBytes, 0);
    return { "kind": "speed", "speed": speed, "remaining": total > 0 ? Math.max(0, Math.ceil(left / speed)) : -1 };
}

// How many files the job covers; 0 when unknown.
function fileCount(details) {
    return details ? Math.max(0, Utils.finiteNumber(details.totalFiles, 0)) : 0;
}

// The last two folders of the destination ("Documents/Holiday"), or "" when it has none.
function destination(details) {
    const url = details && details.destUrl ? String(details.destUrl) : "";
    if (url.length === 0)
        return "";
    let path = url.replace(/^[a-z][a-z0-9+.-]*:\/\/[^\/]*/i, "");
    try {
        path = decodeURIComponent(path);
    } catch (e) {
    }
    return path.split("/").filter(part => part.length > 0).slice(-2).join("/");
}

// The job's byte counts, for the Live page's combined progress; 0 when a job does not report them.
function bytes(details) {
    return { "processed": details ? Math.max(0, Utils.finiteNumber(details.processedBytes, 0)) : 0, "total": details ? Math.max(0, Utils.finiteNumber(details.totalBytes, 0)) : 0 };
}

// Where a click on the job goes: { kind: "show", url } to show it in the file manager, or { kind: "none" } when the job
// reports no usable destination (browsers often report none). Trash jobs show trash:/, local paths become file URLs,
// anything with a scheme (sftp, smb ...) is passed on as it is. Never parses job text (D-27).
function openTarget(details) {
    const dst = details ? TextUtils.cleanText(firstText([details.destUrl, details.descriptionValue2])) : "";
    if (dst.length === 0)
        return { "kind": "none" };
    if (/^trash:/i.test(dst))
        return { "kind": "show", "url": "trash:/" };
    if (dst.charAt(0) === "/")
        return { "kind": "show", "url": "file://" + dst.split("/").map(encodeURIComponent).join("/") };
    if (/^[a-z][a-z0-9+.-]*:/i.test(dst))
        return { "kind": "show", "url": dst };
    return { "kind": "none" };
}
