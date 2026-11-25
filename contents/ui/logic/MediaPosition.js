.pragma library

// A browser (Firefox on YouTube) reports Position 0 a few seconds into a video until the page next publishes a
// position (seek, speed change, pause), so for a browser a 0 means "unknown", not "start". Keep our own clock from the
// last known position instead, advancing at the player's rate. Players that report positions properly are not touched.
// held: { key, pos, at, playing, rate } (pos in µs, at in ms). Returns the new held; held.pos is what to show.
// input: { key, playing, reported, rate, browser, length }.
function step(held, input, nowMs) {
    const sameTrack = !!held && held.key === input.key;
    const trusted = input.reported > 0 || !input.browser || !sameTrack;
    const elapsed = sameTrack && held.playing ? (nowMs - held.at) * 1000 * held.rate : 0;
    let pos = trusted ? input.reported : held.pos + elapsed;
    if (input.length > 0)
        pos = Math.min(pos, input.length);
    return { "key": input.key, "pos": pos, "at": nowMs, "playing": input.playing, "rate": input.rate > 0 ? input.rate : 1 };
}

// Whether a position readout can be seen. popupMode stays "deck" after the deck closes, so a closed deck must fall
// through to the compact pill check instead of reading as "not visible".
// s: { deckMode, dialogVisible, islandOpen, activityPopup, popupActivityIsMedia, panelHidden, compactIsMedia }.
function readoutVisible(s) {
    if (s.deckMode && s.dialogVisible)
        return true;
    if (s.islandOpen)
        return !s.deckMode && s.activityPopup && s.popupActivityIsMedia;
    return !s.panelHidden && s.compactIsMedia;
}
