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

// Job progress (D-45): the fill brightens toward the tip, and a static glow sits on the leading edge. Tune here.
const progressTipFrom = "#8d8f96";
const progressTipMid = "#d1d3d8";
const progressTipEnd = "#ffffff";
const progressTipMidStop = 0.6;     // position of the mid colour along the fill
const progressGlowW = 46;           // px, head of the glow (an ellipse centred on the tip)
const progressGlowH = 18;
const progressGlowCore = 0.825;     // white alpha at the centre
const progressGlowMid = 0.27;       // white alpha at progressGlowMidStop
const progressGlowMidStop = 0.3;    // fraction of the radius
const progressGlowEndStop = 0.7;    // alpha is 0 from here out
const progressGlowBlur = 1;         // px

// Semantic (the only non-neutral colour)
const critical = "#ff453a";

// Radii
const radiusCard = 20;
const radiusInner = 14;         // also the radius of the activity tiles (job, keyboard, activity page)
const radiusSmall = 4;          // bar, dot and pill ends; a Rectangle clamps it to half its smaller side
const edgeFadePx = 28;       // D-44
const surfaceControlTop = "#141419";     // the Control Center surface gradient (PopupContent)
const surfaceControlBottom = "#09090c";

// Icons and states
const iconHeader = 18;       // leading icon of a card header
const iconTransport = 16;    // previous and next
const iconTransportPrimary = 22;  // play and pause
const disabledOpacity = 0.45;

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
const easingStandard = 6;    // Easing.OutCubic; the Easing enum is not reachable from a library script

// Several theme icons used by the modules are full-colour and opaque, so they
// cannot be tinted monochrome. Map them to symbolic/monochrome equivalents.
const symbolicIcons = {
    "preferences-system-bluetooth": "network-bluetooth",
    "kdeconnect": "kdeconnect-tray",
    "preferences-desktop-theme": "color-management-symbolic",
    "preferences-desktop-theme-global": "color-management-symbolic",
    "battery-profile-balanced": "battery-profile-balanced-symbolic",
    "battery-profile-performance": "battery-profile-performance-symbolic",
    "battery-profile-powersave": "battery-profile-powersave-symbolic",
    "multimedia-player": "multimedia-player-symbolic",
    "systemsettings": "configure",
    "brightness-medium": "brightness-low",
    "battery-charging": "battery-060-charging"
};

function symbolic(name) {
    return symbolicIcons[name] || name;
}

// Cursor glow (D-41), tunable. alpha(d) = intensity * exp(-falloff * (d / radius)^2): no visible edge, about 0 at radius.
const glowRadius = 200;      // px
const glowIntensity = 0.05;  // peak white alpha
const glowFalloff = 11;
const glowTauMs = 23;        // follow time constant, frame-rate independent
const glowFadeMs = 350;
const glowSettlePx = 0.3;    // stop asking for frames within this distance of the pointer

// The deck (D-51). Cell units follow D-48: Small 2x1, Wide 4x1, Tall 2x2.
const deckCellW = 170;
const deckCellH = 120;
const deckInset = 16;           // bottom strip kept free for the page indicator
const deckDot = 5;
const deckPillW = 14;
const deckGear = 11;
const deckHit = 22;             // click target around an indicator mark
const deckSpacing = 4;
const deckDimOpacity = 0.4;
const deckTileOpacity = 0.08;
const controlWidth = 430;
const controlHeight = 540;
const controlEditWidth = 620;
const controlEditHeight = 570;
const motionPage = 340;         // silhouette morph between pages
const motionFade = 160;         // content cross-fade

// The Live page (D-51): job tiles and the job list.
const liveGap = 8;
const liveTilePadding = 10;
const liveChip = 32;
const liveGlyph = 18;
const liveRowHeight = 30;
const liveRowBar = 3;
const liveHeaderHeight = 24;
const liveFade = 24;            // the list's bottom fade where more rows lie beyond
const liveMediaNudge = 2;       // the media card draws its artwork this far outside its own box
const liveHairlineAlpha = 0.5;  // the line between the media card and the job list
