.pragma library
.import "WidgetRegistry.js" as Registry
.import "WidgetNotes.js" as WidgetNotes
.import "WidgetOptions.js" as WidgetOptions

// The settings form of a placement, generated from its manifest schema (P11, D-56). Returns plain data; the QML form maps
// each `control` to an editor. Widgets ship no settings screens.

// The control for a schema field. Every enum opens the picker page (D-64); a number is a stepper;
// "app" is reserved (no widget uses it yet) and has no editor.
function controlFor(f) {
    switch (f.type) {
    case "bool":
        return "switch";
    case "enum":
        return "picker";
    case "string":
        return "text";
    case "note":
        return "note";
    case "number":
        return "stepper";
    default:
        return f.type;
    }
}

// The most options any enum field of the manifest has: the picker page needs room for that many.
function pickerCount(manifest) {
    return manifest.settings.reduce((most, f) => f.type === "enum" ? Math.max(most, f.options.length) : most, 0);
}

// What a number field shows: its zero label at 0 ("None"), else the value with its unit ("25 min").
function valueText(field, value) {
    if (value === 0 && field.zero)
        return field.zero;
    return field.unit ? value + " " + field.unit : String(value);
}

function optionLabel(f, option, localeName) {
    return f.labels && f.labels[option] ? Registry.text(f.labels[option], localeName) : option;
}

// The fields a span shows: a field with a "spans" list appears only for those spans (its stored value is kept when hidden).
function visibleFields(manifest, span) {
    return manifest.settings.filter(f => f.spans === undefined || f.spans.indexOf(span) >= 0);
}

// manifest, placement: { span, settings, settingsVersion }, fitsSpan(span) -> bool for this placement's cell, env: what the
// machine offers (WidgetOptions.js), optional.
function build(manifest, placement, fitsSpan, localeName, env) {
    const values = Registry.resolveSettings(manifest, placement.settings, placement.settingsVersion);
    return {
        "title": Registry.text(manifest.name, localeName),
        "size": {
            "current": placement.span,
            "options": manifest.spans.map(span => ({ "value": span, "enabled": span === placement.span || fitsSpan(span) }))
        },
        "fields": visibleFields(manifest, placement.span).map(f => ({
            "key": f.key,
            "type": f.type,
            "control": controlFor(f),
            "label": Registry.text(f.label, localeName),
            "value": f.type === "note" ? null : values[f.key],
            "note": f.type === "note" ? WidgetNotes.describe(manifest.id, values) : null,
            "shown": f.type === "enum" ? optionLabel(f, values[f.key], localeName) : "",
            "options": f.type === "enum" ? f.options.map(o => ({ "value": o, "label": optionLabel(f, o, localeName), "enabled": WidgetOptions.enabled(manifest.id, f.key, o, env) })) : [],
            "unit": f.unit ? Registry.text(f.unit, localeName) : "",
            "zero": f.zeroLabel ? Registry.text(f.zeroLabel, localeName) : "",
            "min": f.min,
            "max": f.max,
            "step": f.step
        }))
    };
}
