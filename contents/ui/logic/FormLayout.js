.pragma library
.import "Presets.js" as Presets

// Where the pieces of a widget's settings form go (D-56): one arrangement for every widget and span. A full-width stage on
// top holds the widget centred at real size, never scaled; below it the size row, the fields in two columns (the first
// half left, the rest right) and the Remove widget row. The panel's width follows the span. The window is pre-sized for the
// most the registry allows, so the form never scrolls and rows are never squeezed.
// geom: cellW, cellH, padding, gap, editInset, editGap, editRow, editEntry, editNote, editChipH, editStageH, editStagePad, editFormMinW.

function box(pageType, span, geom) {
    const cell = ({ "small": [2, 1], "wide": [4, 1], "tall": [2, 2] })[pageType] || [2, 1];
    const boxes = Presets.boxes(pageType, cell[0] * geom.cellW - 2 * geom.padding, cell[1] * geom.cellH - 2 * geom.padding, geom.gap, Presets.pack(pageType, [span]));
    return boxes.length > 0 ? boxes[0] : { "w": geom.cellW, "h": geom.cellH };
}

function rowHeight(type, geom) {
    return type === "note" ? geom.editNote : geom.editRow;
}

// The picker page's height for `count` options in two columns (D-64).
function pickerHeight(count, geom) {
    return count > 0 ? Math.ceil(count / 2) * geom.editEntry + (Math.ceil(count / 2) - 1) * geom.gap : 0;
}

// `types` are the manifest's field types in order. cols lists field indexes per column. `pickerCount` is the most options any
// enum has: the picker page gets at least that room, so opening it does not resize the island.
function plan(types, span, pageType, geom, pickerCount) {
    const b = box(pageType, span, geom);
    const all = types.map((t, i) => i);
    const half = Math.ceil(all.length / 2);
    const cols = [all.slice(0, half), all.slice(half)];
    let tallest = 0;
    for (const col of cols) {
        let h = 0;
        for (const i of col)
            h += rowHeight(types[i], geom);
        tallest = Math.max(tallest, h);
    }
    const stageH = geom.editStageH + 2 * geom.editStagePad;
    return {
        "box": b,
        "cols": cols,
        "stageH": stageH,
        "width": Math.max(geom.editFormMinW, b.w + 2 * geom.editStagePad + 2 * geom.editInset),
        "contentH": Math.max(stageH + geom.editGap + geom.editRow + tallest + geom.editGap + geom.editChipH, pickerHeight(pickerCount || 0, geom))
    };
}
