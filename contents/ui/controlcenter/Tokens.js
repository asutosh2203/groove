.pragma library

// Design tokens for the Control Center. Monochrome, graphite surfaces with
// restrained borders, matching the expanded media card. Only plain constants
// live here so every tile can import it with: import "Tokens.js" as T

// Surfaces
const dialog = "#0b0b0e";
const card = "#121215";
const cardHover = "#17171b";
const cardPressed = "#1d1d22";
const raised = "#1a1a1f";
const chip = "#26262c";
const track = "#25252b";
const sliderTrack = "#1d1d22";
const row = "#17171b";
const rowHover = "#1d1d22";

// Lines
const border = "#25252b";
const borderStrong = "#34343c";
const focusRing = "#8cffffff";

// Text
const textPrimary = "#ffffff";
const textSecondary = "#8d8f99";
const textTertiary = "#5f616b";
const textCaption = "#9a9ca6";

// Neutral fills (sliders, progress, active glyphs)
const fill = "#e6e6ea";
const fillSoft = "#dcdde3";
const iconActive = "#ffffff";
const iconIdle = "#9a9ca6";
const iconOnFill = "#17171b";

// Semantic (the only non-neutral colour)
const critical = "#ff453a";

// Radii
const radiusCard = 20;
const radiusInner = 14;

// Spacing
const gap = 8;
const padding = 12;
const paddingCompact = 8;

// Type (pixel sizes)
const fontTitle = 14;
const fontHeader = 13;
const fontBody = 11;
const fontCaption = 10;

// Motion (ms)
const motionFast = 120;
const motionSlider = 90;

// Several theme icons used by the modules are full-colour and opaque, so they
// cannot be tinted monochrome. Map them to symbolic/monochrome equivalents.
const symbolicIcons = {
    "preferences-system-bluetooth": "network-bluetooth",
    "kdeconnect": "kdeconnect-tray",
    "preferences-desktop-theme": "color-management",
    "preferences-desktop-theme-global": "color-management",
    "systemsettings": "configure",
    "brightness-medium": "brightness-low",
    "battery-charging": "battery-060-charging"
};

function symbolic(name) {
    return symbolicIcons[name] || name;
}
