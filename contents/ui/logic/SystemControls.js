.pragma library
.import "Utils.js" as Utils

// The decisions behind the Control Center's system controls, as pure functions: brightness and volume conversions, the
// command for a power action, the next power profile, what to call the battery, the profile face. The service reads the
// devices and applies the results; nothing here touches hardware.

// --- screen brightness ---------------------------------------------------------------------------------------------

// The percent of the primary display, or -1 when the display is not known yet (use displayRowPercent then).
function screenPercent(displayName, value, max) {
    if (displayName.length > 0 && max > 0)
        return Utils.percentFromRatio(value, max);
    return -1;
}

// The percent from a raw display row: the first usable of the two value roles and of the two maximum roles.
function displayRowPercent(values, maxes) {
    return Utils.percentFromRatio(Utils.firstValidNumber(values, 0), Utils.firstValidNumber(maxes, 100));
}

// While a drag is pinned the slider shows the dragged value, not the device's.
function displayedScreenPercent(available, pinned, visualPercent, actualPercent) {
    if (!available)
        return 0;
    return pinned ? visualPercent : actualPercent;
}

// A device report arrived: the new known values, and whether the pinned slider value is released.
function syncDisplay(displayName, value, max, pinned, visualPercent) {
    const safeMax = Math.max(1, Math.round(Utils.finiteNumber(max, 100)));
    const safeValue = Math.round(Utils.clampNumber(value, 0, safeMax));
    const percent = Utils.percentFromRatio(safeValue, safeMax);
    const release = !pinned || Math.abs(percent - visualPercent) <= 1;
    return {
        "displayName": displayName || "",
        "value": safeValue,
        "max": safeMax,
        "visualPercent": release ? percent : visualPercent,
        "pinned": release ? false : pinned
    };
}

// Setting a percent: the slider pins at it; a known display gets an absolute value, otherwise a ratio step.
function screenTarget(percentInput, displayName, max, currentPercent) {
    const percent = Math.round(Utils.clampNumber(percentInput, 0, 100));
    const known = displayName.length > 0 && max > 0;
    return {
        "percent": percent,
        "absolute": known ? Math.round(max * percent / 100) : null,
        "ratio": (percent - currentPercent) / 100
    };
}

// --- keyboard backlight ---------------------------------------------------------------------------------------------

function keyboardPercent(available, max, value) {
    if (!available || max <= 0)
        return 0;
    const v = Utils.finiteNumber(value, 0);
    const m = Utils.finiteNumber(max, 0);
    return m > 0 ? Utils.percentFromRatio(v, m) : 0;
}

// The absolute value to set, or null when there is no backlight.
function keyboardTarget(available, max, percentInput) {
    if (!available || max <= 0)
        return null;
    return Math.round(max * Utils.clampNumber(percentInput, 0, 100) / 100);
}

// --- volume ---------------------------------------------------------------------------------------------------------

// 0..150, where `normal` is the sink's 100 % volume.
function volumePercent(volume, normal) {
    return Math.max(0, Math.min(150, Utils.percentFromRatio(Utils.finiteNumber(volume, 0), normal)));
}

function volumeTarget(percentInput, normal) {
    return Math.round(normal * Utils.clampNumber(percentInput, 0, 150) / 100);
}

// --- power ----------------------------------------------------------------------------------------------------------

// The shell command for a power action, or null for anything unknown. Never run from a test: the service hands it to
// the command runner, which a test replaces.
function powerCommand(action) {
    switch (action) {
    case "lock":
        return "loginctl lock-session";
    case "logout":
        return "qdbus6 org.kde.Shutdown /Shutdown logout";
    case "sleep":
        return "systemctl suspend";
    case "hibernate":
        return "systemctl hibernate";
    case "reboot":
        return "systemctl reboot";
    case "shutdown":
        return "systemctl poweroff";
    default:
        return null;
    }
}

// The profile after the active one, wrapping round; null when the system offers none.
function nextProfile(profiles, active) {
    if (!profiles || profiles.length <= 0)
        return null;
    const current = profiles.indexOf(active);
    return profiles[(Math.max(0, current) + 1) % profiles.length];
}

function profileIcon(active) {
    if (active === "performance")
        return "battery-profile-performance";
    if (active === "power-saver")
        return "battery-profile-powersave";
    return "battery-profile-balanced";
}

// Which name to show: "performance" | "saver" | "balanced".
function profileKind(active) {
    if (active === "performance")
        return "performance";
    if (active === "power-saver")
        return "saver";
    return "balanced";
}

// "percent" (show the charge), "ac" (a desktop on mains) or "power" (a desktop with no battery on battery).
function batteryKind(hasInternalBatteries, pluggedIn) {
    if (!hasInternalBatteries)
        return pluggedIn ? "ac" : "power";
    return "percent";
}

// --- the user's face ------------------------------------------------------------------------------------------------

function accountIconUrl(out) {
    return out.length > 0 ? (out.indexOf("file:") === 0 ? out : "file://" + out) : "";
}

function faceUrl(profileImageUrl, username) {
    if (profileImageUrl.length > 0)
        return profileImageUrl;
    const user = username || "";
    return user.length > 0 ? "file:///var/lib/AccountsService/icons/" + user : "";
}

// --- keyboard layout ------------------------------------------------------------------------------------------------

// The short, display and long names of the current layout, each falling back to the one before it.
function layoutNames(layoutsList, index) {
    const names = layoutsList.length > index ? layoutsList[index] : null;
    const short = names ? names.shortName || "" : "";
    const display = names ? names.displayName || short : short;
    return { "short": short, "display": display, "long": names ? names.longName || display : display };
}
