.pragma library

// Some players (Firefox/YouTube after a seek) publish a Metadata update without mpris:length, so the reported
// length drops to 0 for a moment. Keep the last known length while it is still the same track, so the progress bar
// does not vanish. A different track, or a genuine new length, replaces it.
// held: { key, length }. Returns the new { key, length }.
function hold(held, key, length) {
    if (length > 0)
        return { key: key, length: length };
    if (held && held.key === key)
        return held;
    return { key: key, length: 0 };
}
