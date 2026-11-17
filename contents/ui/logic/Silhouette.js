.pragma library
.import "PageFit.js" as PageFit
.import "Presets.js" as Presets

// The little layout drawing on a preset chip (D-56): the page's rectangle and one rectangle per placement that fits, scaled
// to fit a w x h box. cell: { w, h } is a cell's real size, so the drawing has the page's real proportions.
function rects(page, spans, box, cell, gap) {
    const grid = Presets.gridOf(page);
    if (!grid)
        return { "w": 0, "h": 0, "x": 0, "y": 0, "rects": [] };
    const realW = grid.cols * cell.w;
    const realH = grid.rows * cell.h;
    const k = Math.min(box.w / realW, box.h / realH);
    const w = realW * k;
    const h = realH * k;
    const cw = w / grid.cols;
    const ch = h / grid.rows;
    const out = PageFit.report(page, spans).filter(r => r.fits).map(r => ({
        "x": r.col * cw + gap / 2,
        "y": r.row * ch + gap / 2,
        "w": r.cols * cw - gap,
        "h": ch - gap
    }));
    return { "w": w, "h": h, "x": (box.w - w) / 2, "y": (box.h - h) / 2, "rects": out };
}
