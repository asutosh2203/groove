.pragma library
.import "Presets.js" as Presets

// Fit and reflow rules for the preset editor (D-56). Placements pack row by row (Presets.pack); everything here is a
// question about a list of spans on a page type. Pure functions of plain data.

function fits(page, spans) {
    return Presets.pack(page, spans) !== null;
}

// Which placements show on the page and which do not: a placement that cannot be added to the ones before it is unfit
// (a stored preset can hold more than its page takes, D-54). Returns [{ index, fits, col, row, cols }] in list order.
function report(page, spans) {
    const kept = [];
    const out = [];
    spans.forEach((span, index) => {
        const trial = kept.concat([span]);
        if (fits(page, trial)) {
            kept.push(span);
            out.push({ "index": index, "fits": true });
        } else {
            out.push({ "index": index, "fits": false });
        }
    });
    const packed = Presets.pack(page, kept) || [];
    let k = 0;
    return out.map(o => o.fits ? Object.assign(o, packed[k++]) : o);
}

// Switching to `type`: ok when everything fits, else the indexes of what would not.
function canSwitch(type, spans) {
    if (fits(type, spans))
        return { "ok": true, "blocked": [] };
    return { "ok": false, "blocked": report(type, spans).filter(r => !r.fits).map(r => r.index) };
}

// The free 1x1 cells of a page and where in the list a widget added there would go: the number of placements that come
// before the cell in row-major order. [{ col, row, index }]
function emptyCells(page, spans) {
    const packed = Presets.pack(page, spans);
    const grid = Presets.gridOf(page);
    if (!packed || !grid)
        return [];
    const out = [];
    for (let row = 0; row < grid.rows; ++row) {
        for (let col = 0; col < grid.cols; ++col) {
            if (packed.some(p => p.row === row && col >= p.col && col < p.col + p.cols))
                continue;
            out.push({ "col": col, "row": row, "index": packed.filter(p => p.row < row || (p.row === row && p.col < col)).length });
        }
    }
    return out;
}

// Candidate spans that still fit when inserted at `index`.
function spansFitting(page, spans, index, candidates) {
    return candidates.filter(span => fits(page, spans.slice(0, index).concat([span], spans.slice(index))));
}

// The list with one item moved, or null when the new order no longer fits the page.
function move(page, spans, from, to) {
    if (from === to || from < 0 || to < 0 || from >= spans.length || to >= spans.length)
        return null;
    const next = spans.slice();
    next.splice(to, 0, next.splice(from, 1)[0]);
    return fits(page, next) ? next : null;
}

function inside(box, point, slack) {
    return point.x >= box.x - slack && point.x <= box.x + box.w + slack && point.y >= box.y - slack && point.y <= box.y + box.h + slack;
}

// What lies under a point of the page content area (w x h): a placed widget ({ kind: "tile", index }), a free cell
// ({ kind: "cell", index, col, row }: index is where a widget put there would go) or nothing.
function dropTarget(page, spans, w, h, gap, point) {
    const none = { "kind": "none", "index": -1 };
    const packed = Presets.pack(page, spans);
    const grid = Presets.gridOf(page);
    if (!packed || !grid)
        return none;
    const boxes = Presets.boxes(page, w, h, gap, packed);
    for (let i = 0; i < boxes.length; ++i) {
        if (inside(boxes[i], point, gap / 2))
            return { "kind": "tile", "index": i };
    }
    const cw = (w - gap * (grid.cols - 1)) / grid.cols;
    const ch = (h - gap * (grid.rows - 1)) / grid.rows;
    for (const c of emptyCells(page, spans)) {
        if (inside({ "x": c.col * (cw + gap), "y": c.row * (ch + gap), "w": cw, "h": ch }, point, gap / 2))
            return { "kind": "cell", "index": c.index, "col": c.col, "row": c.row };
    }
    return none;
}

// Where the dragged placement `from` ends up in the list when dropped on `target`.
function moveIndex(from, target) {
    return target.kind === "tile" ? target.index : target.index - (from < target.index ? 1 : 0);
}
