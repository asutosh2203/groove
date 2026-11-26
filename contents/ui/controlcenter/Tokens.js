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
const warning = "#e0a63c";      // a row whose context is above 80% full (red above 90%)
// Agent accents (D-45, D-57): colour only marks "needs you"; an unknown agent gets the neutral amber.
const agentAccents = { "claude-code": "#d97757" };
const agentAccentDefault = "#e0a63c";

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
const easingPulse = 19;       // Easing.InOutSine: a slow, even breath

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
const deckPadding = 12;         // equal padding on all four sides of a page
const deckGlyph = 14;
const deckCapsuleGap = 7;        // below the island
const deckCapsuleItem = 22;      // each item and its click target
const deckCapsulePad = 8;        // horizontal padding inside the capsule
const deckCapsuleHeight = 30;
const deckDotSize = 5;
const deckDotActiveWidth = 12;   // the current page's dot stretches to a short pill
const deckSettle = 4;            // the capsule settles down this far as it fades in
const deckSlideDistance = 24;   // how far a page slides during a transition
// The welcome page (D-69)
const welcomeIconTile = 44;      // the rounded square holding the step's glyph
const welcomeIcon = 22;
const headerButton = 24;         // a round Control Center header button (the pencil is the same size)
const headerButtonGlyph = 14;
const welcomeSlide = 8;          // how far a card slides in on a change of step
// Capsule scrub (D-62)
const scrubThreshold = 4;        // px of horizontal travel before a press becomes a scrub
const scrubDwell = 120;          // ms: 0 switches the page on every crossing; > 0 only after resting that long (or on release)
const scrubSwell = 0.06;         // the capsule's extra scale while scrubbing
const scrubSwellMs = 140;
const scrubDetentFrom = 0.85;    // the highlight snaps in from this scale and overshoots to 1
const scrubDetentMs = 160;
const scrubOvershoot = 1.7;      // OutBack overshoot
const easingOvershoot = 34;      // Easing.OutBack
const scrubPopMs = 140;          // same-size page change while scrubbing: a fade with a hint of scale
const scrubPopScale = 0.97;
const motionHover = 300;        // hover brightening, shared with the job tiles
const deckSpacing = 4;
const deckTileOpacity = 0.08;
const controlWidth = 430;
const controlHeight = 540;
const controlEditWidth = 620;
const controlEditHeight = 570;
// The preset editor (D-56): chrome sizes around the page at real size, and the zoom on entry.
const editInset = 14;
const editBar = 34;
const editChips = 44;
const editGap = 10;
const editSidebar = 150;
const editSidebarMinH = 210;
const editHint = 24;
const editOutlinePad = 8;
const editZoom = 1.04;
const editRow = 44;
const editStageH = 104;            // the form's preview stage: tall enough for the tallest widget box
const editStagePad = 12;
const editFormMinW = 640;          // two columns of fields
const editFieldW = 160;            // a text, place or time zone field in the form
const editNote = 28;               // a computed read-only line in the form
const editBadge = 18;              // the "−" badge on a widget and a chip
const editEntry = 40;              // a catalogue row
const editSearchPause = 500;       // ms of quiet before a place search starts
const editChipW = 44;
const editChipH = 28;
const stepHoldDelay = 400;          // ms a stepper button is held before it repeats
const stepRepeatSlow = 160;        // ms between repeats at first, ramping down to the fast rate
const stepRepeatFast = 45;
const stepRampRepeats = 12;
const editSilhouetteGap = 2;
const motionPulse = 1100;       // one way of a working row's dot breathing between white and grey
const motionPage = 340;         // silhouette morph between pages
const motionFade = 160;         // content cross-fade

// The Live page (D-52): job tiles and the job list.
const liveGap = 8;
const liveTilePadding = 10;
const liveChip = 32;
const liveGlyph = 18;
const liveRowHeight = 30;
const liveRowBar = 3;
const liveHeaderHeight = 24;
const liveFadeMore = 44;        // the list's fade and chevron where rows lie beyond (clearly visible)
const liveHairlineAlpha = 1;    // the line between the media card and the job list
const liveMediaGap = 16;        // room around that line: half above it, half below
const compactInsetLeft = 4;     // the closed capsule's agent text and bar
const compactInsetRight = 2;
const compactGap = 3;
const compactBar = 3;
const compactDot = 3;           // the dot between the project and the tail
const secondTick = 1000;        // ms: a seconds clock on an open deck (a command timer, an exact-sleep countdown)
const countdownTick = 5000;     // ms: the closed capsule's countdown bar
const minuteTick = 60000;       // ms: the elapsed minutes of an agent run
const liveSubBadge = 14;        // the mini prompt behind an agent's glyph while subagents run
const liveLineGlyph = 12;       // the glyph at the start of an agent tile's action line
const liveBadge = 8;            // the accent dot on an agent's glyph while it waits
const liveBadgeInset = 3;
const liveBadgeRow = 6;         // the same dot on a compact row's smaller glyph
const liveTileHeight = 96;      // a job row opened in place (accordion) is as tall as a tile
const hoverInset = 4;           // a row's hover highlight sits this far inside its rounded container (D-61)
const hoverScale = 1.02;        // the media card's artwork grows this much on hover
const fileManagerRaiseDelay = 450;  // ms to let the file manager show an item before its window is raised

// Widgets (D-54, D-55): the tile surface, its text scale and the hover peek.
const widgetPadding = 10;
const widgetHeroSize = 32;
const widgetHeroSizeSmall = 20;
const widgetHeroWeight = 500;
const widgetGlyph = 24;             // the weather condition glyph on a tile
const widgetGlyphSmall = 18;        // a day or hour column's glyph
const widgetSunGlyph = 12;          // the sun glyph in the detail line
const widgetSkeletonHeight = 8;
const widgetDayColumn = 46;         // minimum width of a day or hour column
const widgetLabelGlyph = 16;        // the moon beside a tile's label
const widgetRing = 30;              // the usage ring's diameter
const widgetRingStroke = 4;
const widgetHairline = 2;           // a row's context-fill line
const widgetUsageWidth = 44;        // the resting usage lines, right-aligned beside the moon
const widgetRowLift = 1.03;         // a waiting row that slides up into a freed slot
const widgetTallRoom = 100;         // a box this tall has room for an extra line (the Pomodoro widget)
const pomodoroCoarseTick = 5000;   // ms: the capsule's minutes and thin bar step while a timer runs
const pomodoroFineTick = 1000;     // ms: mm:ss, only while a view that shows it exists
const pomodoroSegmentGap = 2;      // between the 4x1 timeline's segments
const pomodoroDotInset = 1;        // the light fill sits inside the dot's outline
const pomodoroDot = 10;            // a round dot in the 2x1
const pomodoroBar = 6;             // a timeline segment's height in the 4x1
const widgetButton = 24;           // the Pomodoro play and skip click targets (at least 22)
const sysmonWindowSec = 120;        // s: the graph's span and the history kept (change this one number to change both)
const sysmonVisibleTick = 1000;     // ms: sampling while a System Monitor view shows
const sysmonHiddenTick = 5000;      // ms: sampling otherwise (history and alerts); stopped while the screen is locked
const sysmonGapFactor = 3;          // a gap wider than this many ticks breaks the line (lock, suspend)
const sysmonHotLoad = 90;           // % of CPU, GPU or RAM
const sysmonHotCpuTemp = 90;        // deg C
const sysmonHotGpuTemp = 85;        // deg C
const sysmonCoolBy = 5;             // the hero cools only below threshold minus this
const sysmonSparkStroke = 1.5;
const sysmonFillAlpha = 0.16;       // the area under the line, at its top
const sysmonFillAlphaHot = 0.32;    // and while the stat is hot
const sysmonAlertSustainLoadSec = 60;   // s hot before a CPU or GPU load alert
const sysmonAlertSustainRamSec = 30;
const sysmonAlertSustainTempSec = 30;
const sysmonAlertCooldownSec = 600;     // s between alerts of one sensor, whatever shows it
const sysmonReadySec = 10;          // s a sensor may take to give a first value
const sysmonRateFloor = 102400;     // B/s: a rate graph never scales below this, so an idle line is not noise
const sysmonWarmMs = 1000;          // ms after sensors wake before their values count (the daemon's first sample)
const widgetPeekDwell = 150;        // ms of hover before the detail line peeks
