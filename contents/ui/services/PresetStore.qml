pragma ComponentBehavior: Bound

import QtQuick
import "../logic/Presets.js" as Presets
import "../logic/WidgetRegistry.js" as Registry
import "../widgets/Manifests.js" as Manifests

// The widget registry and the island's presets (D-54). Inputs are the two config strings: `devPresets` (hidden, wins when
// set) and `presets` (what the preset editor will write). Validation decides what shows and never rewrites what is
// stored. A bad blob or manifest is logged and skipped; nothing here throws.
Item {
    id: store

    required property string devPresets
    required property string storedPresets

    readonly property var registry: Registry.build(Manifests.list)
    readonly property string activeText: store.devPresets.trim().length > 0 ? store.devPresets : store.storedPresets
    readonly property var result: Presets.evaluate(store.activeText, store.registry)
    readonly property var presets: store.result.presets
    // The locations the presets' Weather placements use, for WeatherHub; "island" is not listed.
    readonly property var weatherLocations: store.registry.byId.weather ? store.presets.reduce((all, preset) => all.concat(preset.placements), []).filter(placement => placement.widget === "weather").map(placement => Registry.resolveSettings(store.registry.byId.weather, placement.settings, placement.settingsVersion).location).filter(location => location !== "island") : []
    // The pids of every placement, for the timer hub: a timer whose placement is gone is dropped.
    readonly property var placementPids: store.presets.reduce((all, preset) => all.concat(preset.placements.map(placement => placement.pid)), [])

    function report() {
        store.result.log.forEach(line => console.warn("groove:", line));
        store.registry.skipped.forEach(skipped => console.warn("groove: widget", skipped.id, "skipped:", skipped.errors.join("; ")));
    }

    onResultChanged: store.report()
    Component.onCompleted: store.report()
}
