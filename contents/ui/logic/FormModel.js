.pragma library
.import "WidgetRegistry.js" as Registry
.import "WidgetNotes.js" as WidgetNotes

// The settings form of a placement, generated from its manifest schema (P11, D-56). Returns plain data; the QML form maps
// each `control` to an editor. Widgets ship no settings screens.

// The control for a schema field. Enums of up to four options are segmented, else a dropdown; a number is a stepper;
// "app" is reserved (no widget uses it yet) and has no editor.
function controlFor(f) {
    switch (f.type) {
    case "bool":
        return "switch";
    case "enum":
        return f.options.length <= 4 ? "segmented" : "dropdown";
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

// What a number field shows: its zero label at 0 ("None"), else the value with its unit ("25 min").
function valueText(field, value) {
    if (value === 0 && field.zero)
        return field.zero;
    return field.unit ? value + " " + field.unit : String(value);
}

function optionLabel(f, option, localeName) {
    return f.labels && f.labels[option] ? Registry.text(f.labels[option], localeName) : option;
}

// manifest, placement: { span, settings, settingsVersion }, fitsSpan(span) -> bool for this placement's cell.
function build(manifest, placement, fitsSpan, localeName) {
    const values = Registry.resolveSettings(manifest, placement.settings, placement.settingsVersion);
    return {
        "title": Registry.text(manifest.name, localeName),
        "size": {
            "current": placement.span,
            "options": manifest.spans.map(span => ({ "value": span, "enabled": span === placement.span || fitsSpan(span) }))
        },
        "fields": manifest.settings.map(f => ({
            "key": f.key,
            "type": f.type,
            "control": controlFor(f),
            "label": Registry.text(f.label, localeName),
            "value": f.type === "note" ? null : values[f.key],
            "note": f.type === "note" ? WidgetNotes.describe(manifest.id, values) : null,
            "options": f.type === "enum" ? f.options.map(o => ({ "value": o, "label": optionLabel(f, o, localeName) })) : [],
            "unit": f.unit ? Registry.text(f.unit, localeName) : "",
            "zero": f.zeroLabel ? Registry.text(f.zeroLabel, localeName) : "",
            "min": f.min,
            "max": f.max,
            "step": f.step
        }))
    };
}
