.pragma library
.import "PageFit.js" as PageFit
.import "WidgetRegistry.js" as Registry

// The widget catalogue in the preset editor (D-56): what the registry offers, and whether each widget fits a cell or the page.
// Widgets that fit nowhere are listed as "won't fit", never hidden. Pure functions of plain data.

const spanLabels = { "1x1": "1×1", "2x1": "2×1", "4x1": "4×1" };

// Where a widget goes when added: `index` is the insertion index (a clicked cell's), or null for the first free spot. The
// span is the widget's default when it fits there, else its first span that does. Returns { ok, index, span }.
function placeAt(page, spans, index, manifest) {
    const tries = index === null || index === undefined ? PageFit.emptyCells(page, spans).map(c => c.index).concat([spans.length]) : [index];
    for (const at of tries) {
        const ok = PageFit.spansFitting(page, spans, at, manifest.spans);
        if (ok.length > 0)
            return { "ok": true, "index": at, "span": ok.indexOf(manifest.defaultSpan) >= 0 ? manifest.defaultSpan : ok[0] };
    }
    return { "ok": false, "index": -1, "span": "" };
}

// registry: { byId, ids }. index: as for placeAt. Returns [{ id, name, icon, spans, spansLabel, fits, span }].
function entries(registry, page, spans, index, localeName) {
    return registry.ids.map(id => {
        const m = registry.byId[id];
        const where = placeAt(page, spans, index, m);
        return {
            "id": id,
            "name": Registry.text(m.name, localeName),
            "icon": m.icon,
            "spans": m.spans,
            "spansLabel": m.spans.map(s => spanLabels[s]).join(" · "),
            "fits": where.ok,
            "span": where.span
        };
    });
}
