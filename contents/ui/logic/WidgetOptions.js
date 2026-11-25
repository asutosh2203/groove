.pragma library
.import "Sysmon.js" as Sysmon

// Which options of a widget's enum field exist on this machine (D-65), keyed by manifest id like WidgetNotes.js. An option
// that is not available stays in the picker, disabled; it is never replaced by a placeholder. `env.sensors` is the set of
// sensor ids the daemon lists (null while unknown, which disables nothing). Returns true for every widget without a rule.
function enabled(widgetId, fieldKey, option, env) {
    if (widgetId === "system-monitor" && /^slot[1-4]$/.test(fieldKey))
        return Sysmon.optionAvailable(option, env ? env.sensors : null);
    return true;
}
