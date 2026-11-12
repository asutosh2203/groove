.pragma library
.import "Utils.js" as Utils

// How the island and its containing panel agree on a shape, as pure functions. Notch mode attaches the panel to the
// top edge (not floating, thickness = the shell height); Pill mode restores what the panel was before. The panel's
// original settings are captured once, before the first change, and only count for the panel they came from. The
// service runs the scripting command, keeps the phase, timers and config; nothing here touches the shell.

const replyPrefix = "DI_PANEL ";

// The shell command that reads the panel (applyFloating null, applyThickness 0) or reads and changes it. The panel is
// found by id and confirmed by checking that its widget list contains this applet, so a stale or wrong id never
// touches another panel. Ids are floored so nothing but digits reaches the script.
function command(panelIdInput, appletIdInput, applyFloating, applyThickness) {
    const panelId = Math.floor(Number(panelIdInput));
    const appletId = Math.floor(Number(appletIdInput));
    let apply = "";
    if (applyFloating !== null)
        apply += "p.floating = " + (applyFloating ? "true" : "false") + ";";
    if (applyThickness > 0)
        apply += "p.height = " + Math.floor(applyThickness) + ";";
    const script = "var r = {ok: false}; var p = panelById(" + panelId + "); "
        + "if (p && p.widgetIds.indexOf(" + appletId + ") >= 0) { " + apply
        + " r = {ok: true, id: " + panelId + ", location: p.location, floating: p.floating, height: p.height}; } "
        + "print('" + replyPrefix + "' + JSON.stringify(r));";
    return "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + Utils.shellQuote(script);
}

// The command's output is only a panel reply when it carries the prefix.
function isReply(stdout) {
    return String(stdout).trim().indexOf(replyPrefix) === 0;
}

// { ok, id, location, floating, height } from a reply line, or { ok: false } when it cannot be read.
function parseReply(out) {
    try {
        return JSON.parse(out.substring(replyPrefix.length));
    } catch (e) {
        return { "ok": false };
    }
}

function syncWanted(notch, originalPanelId) {
    return notch || originalPanelId > 0;
}

// What to do with the panel's current state. originals: { panelId, floating (-1 unset, 0, 1), thickness }.
// Returns { warn, capture, apply, clear }: warn (a message or null), capture (the originals to store or null), apply
// ({ action, floating, thickness } or null) and clear (forget the originals).
function decide(state, originals, notch, notchThickness) {
    const out = { "warn": null, "capture": null, "apply": null, "clear": false };
    if (state.location !== "top") {
        out.warn = "panel is not on the top edge, leaving it untouched";
        return out;
    }
    // Originals only count for the panel they were captured from.
    const stored = originals.panelId === state.id && originals.floating >= 0;
    if (notch) {
        const attached = !state.floating && state.height === notchThickness;
        if (!stored) {
            // Capture once, before the first change. An already attached panel with no record has an unknown
            // thickness: remember only that it floated.
            out.capture = {
                "panelId": state.id,
                "floating": attached ? 1 : (state.floating ? 1 : 0),
                "thickness": attached ? 0 : state.height
            };
        }
        if (!attached)
            out.apply = { "action": "notch", "floating": false, "thickness": notchThickness };
    } else if (stored) {
        const wantFloating = originals.floating === 1;
        const wantThickness = originals.thickness;
        if (state.floating === wantFloating && (wantThickness <= 0 || state.height === wantThickness))
            out.clear = true;
        else
            out.apply = { "action": "restore", "floating": wantFloating, "thickness": wantThickness };
    }
    return out;
}

// What a reply to a change means. action: "restore" | "notch". Returns { clear, warn }.
function evaluateApply(reply, action, originals, notchThickness) {
    if (action === "restore") {
        if (reply.floating === (originals.floating === 1) && (originals.thickness <= 0 || reply.height === originals.thickness))
            return { "clear": true, "warn": null };
        return { "clear": false, "warn": "panel restore did not fully apply; original settings kept for a retry" };
    }
    if (reply.floating || reply.height !== notchThickness)
        return { "clear": false, "warn": "panel did not accept the notch settings" };
    return { "clear": false, "warn": null };
}

// The index of the screen nearest to a point (a point inside a screen has distance 0), or -1 with no usable screen.
function nearestScreen(screens, pointX, pointY) {
    let nearest = -1;
    let nearestDistance = Number.POSITIVE_INFINITY;
    for (let i = 0; i < screens.length; ++i) {
        const screen = screens[i];
        const left = Utils.finiteNumber(screen.virtualX, 0);
        const top = Utils.finiteNumber(screen.virtualY, 0);
        const width = Math.max(0, Utils.finiteNumber(screen.width, 0));
        const height = Math.max(0, Utils.finiteNumber(screen.height, 0));
        if (width <= 0 || height <= 0)
            continue;

        const right = left + width;
        const bottom = top + height;
        const dx = pointX < left ? left - pointX : pointX > right ? pointX - right : 0;
        const dy = pointY < top ? top - pointY : pointY > bottom ? pointY - bottom : 0;
        const distance = dx * dx + dy * dy;
        if (distance < nearestDistance) {
            nearest = i;
            nearestDistance = distance;
        }
    }
    return nearest;
}
