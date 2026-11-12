.pragma library
.import "TextUtils.js" as TextUtils

// What `bluetoothctl` printed, and what the Control Center says about it. The commands' output is parsed as before
// (a native BluezQt source is a later milestone). Translated text is left to the caller: summary and detail return
// which line applies, never what it is called in the user's language.

// "Device AA:BB:CC Name with spaces" lines -> the names, one per line.
function parseDevices(text) {
    const lines = String(text || "").split("\n");
    const out = [];
    for (let i = 0; i < lines.length; ++i) {
        const line = String(lines[i] || "").trim();
        if (line.length <= 0)
            continue;

        const parts = line.split(/\s+/);
        out.push(parts.length > 2 ? parts.slice(2).join(" ") : line);
    }
    return out.join("\n");
}

function parseAvailable(text) {
    const out = String(text || "");
    return out.indexOf("Controller ") !== -1 || out.indexOf("Powered:") !== -1 || out.indexOf("Alias:") !== -1;
}

function parseAdapterName(text) {
    const lines = String(text || "").split("\n");
    for (let i = 0; i < lines.length; ++i) {
        const line = String(lines[i] || "").trim();
        if (line.indexOf("Alias:") === 0)
            return TextUtils.cleanText(line.slice(6));
        if (line.indexOf("Name:") === 0)
            return TextUtils.cleanText(line.slice(5));
    }
    return "";
}

function parsePowered(text) {
    return TextUtils.cleanText(text).indexOf("Powered: yes") !== -1;
}

function deviceCount(devicesText) {
    if (devicesText.length <= 0)
        return 0;
    return devicesText.split("\n").filter(function(line) {
        return String(line || "").trim().length > 0;
    }).length;
}

// { kind: "noAdapter" | "off" | "on" | "device" (text: its name) | "devices" (count) }
function summary(available, powered, devicesText) {
    if (!available)
        return { "kind": "noAdapter" };
    if (!powered)
        return { "kind": "off" };
    const count = deviceCount(devicesText);
    if (count <= 0)
        return { "kind": "on" };
    return count === 1 ? { "kind": "device", "text": devicesText.split("\n")[0] } : { "kind": "devices", "count": count };
}

// { kind: "unavailable" | "radioOff" | "devices" (text) | "adapter" (text) | "none" }
function detail(available, powered, devicesText, adapterName) {
    if (!available)
        return { "kind": "unavailable" };
    if (!powered)
        return { "kind": "radioOff" };
    if (devicesText.length > 0)
        return { "kind": "devices", "text": devicesText };
    return adapterName.length > 0 ? { "kind": "adapter", "text": adapterName } : { "kind": "none" };
}
