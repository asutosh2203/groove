.pragma library

// The widget registry (D-54): validates manifests and resolves per-placement settings. Pure functions of plain data; no
// QML is instantiated to read a manifest. An invalid manifest is reported, never thrown, so it cannot block the others.

const CONTRACT = 1;
const SPANS = ["1x1", "2x1", "4x1"];
const CATEGORIES = ["Info", "Media", "System", "Dev"];
const SERVICES = ["clock", "weather"];
const TYPES = ["bool", "enum", "string", "number", "location", "timezone", "app"];
const ID = /^[a-z][a-z0-9-]{0,40}$/;
const KEY = /^[a-zA-Z][a-zA-Z0-9]{0,30}$/;
const ZONE = /^[A-Za-z0-9_+\-\/]{1,64}$/;

// Per widget id: [{ from, run(settings) }], each step lifts settings by one version. None are needed yet.
const migrations = {};

function isText(v) {
    return typeof v === "string" && v.length > 0;
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function isLocalised(v) {
    return isObject(v) && isText(v.en);
}

function validLocation(v) {
    return isObject(v) && isText(v.name) && typeof v.lat === "number" && typeof v.lon === "number" && v.lat >= -90 && v.lat <= 90 && v.lon >= -180 && v.lon <= 180;
}

// One field of a manifest's settings schema; returns an error string or "".
function fieldError(f) {
    if (!isObject(f) || !KEY.test(String(f.key)))
        return "settings: a field needs a key";
    const at = "settings." + f.key + ": ";
    if (TYPES.indexOf(f.type) < 0)
        return at + "unknown type";
    if (!isLocalised(f.label))
        return at + "needs a label with an en text";
    if (f.type === "enum" && !(Array.isArray(f.options) && f.options.length > 0 && f.options.every(isText) && f.options.indexOf(f.default) >= 0))
        return at + "needs options and a default that is one of them";
    if (f.type === "number" && !(typeof f.min === "number" && typeof f.max === "number" && typeof f.step === "number" && f.min <= f.max && f.step > 0 && typeof f.default === "number" && f.default >= f.min && f.default <= f.max))
        return at + "needs min, max, step and a default within range";
    if (f.type === "bool" && typeof f.default !== "boolean")
        return at + "default must be true or false";
    if ((f.type === "string" || f.type === "app") && typeof f.default !== "string")
        return at + "default must be a string";
    if (f.type === "timezone" && !(f.default === "local" || ZONE.test(String(f.default))))
        return at + "default must be \"local\" or a zone id";
    if (f.type === "location" && !(f.default === "island" || validLocation(f.default)))
        return at + "default must be \"island\" or { name, lat, lon }";
    return "";
}

// raw: parsed manifest JSON. Returns { ok, manifest, errors }.
function validate(raw) {
    const errors = [];
    if (!isObject(raw))
        return { "ok": false, "manifest": null, "errors": ["not an object"] };
    if (raw.contract !== CONTRACT)
        errors.push("contract must be " + CONTRACT);
    if (!ID.test(String(raw.id)))
        errors.push("id must be lower-case words joined by hyphens");
    if (!isLocalised(raw.name))
        errors.push("name needs an en text");
    if (!isLocalised(raw.description))
        errors.push("description needs an en text");
    const icon = typeof raw.icon === "string" ? [raw.icon] : raw.icon;
    if (!(Array.isArray(icon) && icon.length > 0 && icon.every(isText)))
        errors.push("icon needs a symbolic name or a fallback chain");
    if (!(Array.isArray(raw.spans) && raw.spans.length > 0 && raw.spans.every(s => SPANS.indexOf(s) >= 0)))
        errors.push("spans must be a non-empty subset of " + SPANS.join(", "));
    else if (raw.spans.indexOf(raw.defaultSpan) < 0)
        errors.push("defaultSpan must be one of spans");
    if (CATEGORIES.indexOf(raw.category) < 0)
        errors.push("category must be one of " + CATEGORIES.join(", "));
    if (!(Number.isInteger(raw.version) && raw.version >= 1))
        errors.push("version must be a whole number from 1");
    if (!(Array.isArray(raw.services) && raw.services.every(s => SERVICES.indexOf(s) >= 0)))
        errors.push("services must list only: " + SERVICES.join(", "));
    const keys = {};
    if (!Array.isArray(raw.settings))
        errors.push("settings must be a list");
    else {
        for (const f of raw.settings) {
            const e = fieldError(f);
            if (e.length > 0)
                errors.push(e);
            else if (keys[f.key])
                errors.push("settings." + f.key + ": duplicate key");
            else
                keys[f.key] = true;
        }
    }
    if (errors.length > 0)
        return { "ok": false, "manifest": null, "errors": errors };
    return { "ok": true, "manifest": Object.assign({}, raw, { "icon": icon }), "errors": [] };
}

// rawList: [{ id, manifest }] as the generated mirror lists them. Returns { byId, ids, skipped: [{ id, errors }] }.
function build(rawList) {
    const byId = {};
    const ids = [];
    const skipped = [];
    for (const entry of rawList) {
        const r = validate(entry.manifest);
        const id = r.ok ? r.manifest.id : String(entry.id);
        if (!r.ok)
            skipped.push({ "id": id, "errors": r.errors });
        else if (byId[id] !== undefined)
            skipped.push({ "id": id, "errors": ["duplicate id"] });
        else if (entry.id !== undefined && entry.id !== id)
            skipped.push({ "id": id, "errors": ["id does not match its folder (" + entry.id + ")"] });
        else {
            byId[id] = r.manifest;
            ids.push(id);
        }
    }
    return { "byId": byId, "ids": ids, "skipped": skipped };
}

// Localised text: the exact locale (de_DE), its language (de), then English.
function text(localised, localeName) {
    if (!isObject(localised))
        return "";
    const name = String(localeName || "");
    return localised[name] || localised[name.split(/[_-]/)[0]] || localised.en || "";
}

function defaultFor(f) {
    return f.default;
}

function defaults(manifest) {
    const out = {};
    for (const f of manifest.settings)
        out[f.key] = defaultFor(f);
    return out;
}

function coerce(f, v) {
    switch (f.type) {
    case "bool":
        return typeof v === "boolean" ? v : f.default;
    case "enum":
        return f.options.indexOf(v) >= 0 ? v : f.default;
    case "string":
        return typeof v === "string" && v.length <= 80 ? v : f.default;
    case "app":
        return typeof v === "string" ? v : f.default;
    case "number":
        return typeof v === "number" && isFinite(v) ? Math.min(f.max, Math.max(f.min, v)) : f.default;
    case "timezone":
        return v === "local" || (typeof v === "string" && ZONE.test(v)) ? v : f.default;
    case "location":
        return v === "island" || validLocation(v) ? v : f.default;
    }
    return f.default;
}

// Lifts stored settings to the manifest's version. A version newer than the widget knows is kept as it is.
function migrate(manifest, stored, fromVersion) {
    let settings = isObject(stored) ? stored : {};
    let version = Number.isInteger(fromVersion) && fromVersion >= 1 ? fromVersion : 1;
    const steps = migrations[manifest.id] || [];
    while (version < manifest.version) {
        const step = steps.find(s => s.from === version);
        if (step)
            settings = step.run(settings);
        version += 1;
    }
    return settings;
}

// What a view receives: every field of the schema, taken from the (migrated) stored value or else its default. The stored
// data is never written back from here (D-54), so an unreadable value shows the default and D3 can still show the original.
function resolveSettings(manifest, stored, fromVersion) {
    const migrated = migrate(manifest, stored, fromVersion);
    const out = {};
    for (const f of manifest.settings)
        out[f.key] = coerce(f, migrated[f.key]);
    return out;
}
