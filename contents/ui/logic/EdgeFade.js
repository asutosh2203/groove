.pragma library

// D-44: scrolled content fades into the surface at an edge only when more content lies beyond it.

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

// 0..1 per edge: ramps up with the distance to scroll, so it is crisp at the ends and never pops in.
function strengths(contentY, contentHeight, viewHeight, bottomMargin, fadePx) {
    const remaining = contentHeight + bottomMargin - viewHeight - contentY;
    return { "top": clamp01(contentY / fadePx), "bottom": clamp01(remaining / fadePx) };
}

// Gradient stop positions (0..1 of the view height) where the fades end.
function stops(viewHeight, fadePx) {
    const f = viewHeight > 0 ? Math.min(0.5, fadePx / viewHeight) : 0;
    return { "inner0": f, "inner1": 1 - f };
}

// Linear mix of two [r, g, b] colours.
function mix(a, b, t) {
    const k = clamp01(t);
    return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
}
