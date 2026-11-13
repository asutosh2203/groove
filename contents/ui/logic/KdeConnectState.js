.pragma library
.import "Utils.js" as Utils

// Daemon queries (qdbus6 --literal). Each string must differ so the executable
// engine never merges two in-flight sources.
const daemon = "qdbus6 --literal org.kde.kdeconnect /modules/kdeconnect org.kde.kdeconnect.daemon.deviceNames ";
const pairedCommand = daemon + "false true";
const connectedCommand = daemon + "true true";

// Parses `[Argument: a{ss} {"id" = "name", ...}]` into [{id, name}].
// Quoted strings may contain commas, colons, " = " and backslash-escaped quotes.
function parseNames(text) {
    const body = String(text || "");
    const start = body.indexOf("{");
    if (start < 0)
        return [];
    const strings = [];
    for (let i = start + 1; i < body.length; ++i) {
        if (body.charAt(i) !== '"')
            continue;
        let value = "";
        for (++i; i < body.length && body.charAt(i) !== '"'; ++i) {
            if (body.charAt(i) === "\\" && i + 1 < body.length)
                ++i;
            value += body.charAt(i);
        }
        strings.push(value);
    }
    const out = [];
    for (let j = 0; j + 1 < strings.length; j += 2) {
        if (strings[j].length > 0)
            out.push({ id: strings[j], name: strings[j + 1] });
    }
    return out;
}

// paired and connected are parseNames() results. Unpaired devices never appear:
// the daemon only returns paired ones for both queries.
function buildDevices(paired, connected) {
    const reachable = {};
    for (const d of connected || [])
        reachable[d.id] = true;
    const devices = (paired || []).map(d => ({
        id: d.id,
        name: d.name.trim().length > 0 ? d.name.trim() : "Device",
        reachable: reachable[d.id] === true,
        paired: true
    }));
    devices.sort((a, b) => (b.reachable - a.reachable) || a.name.localeCompare(b.name));
    return devices;
}

function connectedCount(devices) {
    return (devices || []).filter(d => d.reachable).length;
}

// Header subtitle kind: "none", "connected" (count > 0) or "away". Text is translated by the caller.
function summaryKind(devices) {
    if ((devices || []).length === 0)
        return "none";
    return connectedCount(devices) > 0 ? "connected" : "away";
}

// The shell command for a device action ("ring" or "browse"), or null for anything else. The device id comes from another
// device's name list, so it is shell-quoted in both commands (the whole object path in "browse"), never pasted in raw.
function deviceCommand(action, deviceId) {
    if (action === "ring")
        return "kdeconnect-cli --device " + Utils.shellQuote(deviceId) + " --ring";
    if (action === "browse")
        return "qdbus6 org.kde.kdeconnect " + Utils.shellQuote("/modules/kdeconnect/devices/" + deviceId + "/sftp") + " org.kde.kdeconnect.device.sftp.startBrowsing";
    return null;
}
