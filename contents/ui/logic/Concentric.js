.pragma library

// Geometry of a highlight inside a rounded container (D-61).

// The highlight's corner radius: concentric with the container's corner, which it sits `inset` inside.
function radius(outer, inset) {
    return Math.max(0, outer - inset);
}

// The margin that puts one edge of the highlight `inset` inside the container, for a row whose own edge is `gap`
// inside it on that side. Negative: the highlight reaches past the row into its padding.
function margin(gap, inset) {
    return inset - gap;
}
