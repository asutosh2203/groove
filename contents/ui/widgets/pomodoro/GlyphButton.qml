import "../.." as Island
import "../../controlcenter/Tokens.js" as T

// The Pomodoro buttons (D-64): the shared island button in the Control Center's filled style, a resting fill in the muted tile
// tone that brightens on hover over the shared hover fade. An action that does nothing is `enabled: false`, which dims it
// (it stays visible). 24 px, at least the 22 px click target.
Island.IslandButton {
    compact: true
    restColor: T.chip
    hoverColor: T.borderStrong
    pressedColor: T.borderStrong
    outlineColor: T.border
    focusColor: T.focusRing
    fadeMs: T.motionHover
}
