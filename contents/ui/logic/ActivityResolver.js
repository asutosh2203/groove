.pragma library

// Which activity the island shows, and how a new one gets in (D-13, D-35). Providers are "activity-like" objects with
// key, active, priority and the display fields (title, subtitle, artwork, progress*, mediaControlsVisible,
// autoCloseMs); the controller hands in its live providers, a test hands in plain objects. Everything here is a pure
// function of those, so pre-emption can be tested without a shell.

// Priorities (D-38), highest first: a Critical notification, a keyboard layout announcement, a Normal notification, a
// job, media, then idle. A Low notification is not an activity at all (it shows no popup and pre-empts nothing; it only
// lands in the Control Center list). Media is the floor above idle, so a message pre-empts the music and the music
// returns when the message ends (D-13). The urgency kind comes from Notifications.urgencyKind, which maps KDE's enum
// (Low 1, Normal 2, Critical 4) explicitly; nothing here compares urgency numbers.
const priority = { "idle": 0, "media": 100, "job": 200, "noticeNormal": 300, "keyboard": 350, "noticeCritical": 400 };

// The priority of a presented notification of this urgency kind ("critical" or "normal"; anything else is not an
// activity, so it has none).
function noticePriority(kind) {
    switch (kind) {
    case "critical":
        return priority.noticeCritical;
    case "normal":
        return priority.noticeNormal;
    default:
        return priority.idle;
    }
}

function byKey(providers, key) {
    for (let i = 0; i < providers.length; ++i) {
        const provider = providers[i];
        if (provider && provider.key === key)
            return provider;
    }
    return null;
}

// The active provider with the highest priority; the first one wins a tie. Null when nothing is active.
function highest(providers) {
    let selected = null;
    for (let i = 0; i < providers.length; ++i) {
        const candidate = providers[i];
        if (!candidate || !candidate.active)
            continue;
        if (!selected || candidate.priority > selected.priority)
            selected = candidate;
    }
    return selected;
}

// The provider asked for if it is active, else `current` (the highest).
function pick(providers, current, requestedKey) {
    if (requestedKey && requestedKey !== "auto") {
        const requested = byKey(providers, requestedKey);
        if (requested && requested.active)
            return requested;
    }
    return current;
}

function keyOf(provider) {
    return provider ? provider.key : "idle";
}

function priorityOf(provider) {
    return provider ? provider.priority : 0;
}

// How long an activity popup stays up: at least a second, 3 s when unknown.
function autoCloseMs(provider) {
    const ms = provider ? Number(provider.autoCloseMs) : 3000;
    return isFinite(ms) ? Math.max(1000, ms) : 3000;
}

// A display field of a provider, or a fallback when there is none.
function field(provider, name, fallback) {
    return provider ? provider[name] : fallback;
}

// What to do when something asks for an activity popup (bump):
//   "ignore"  - the requested activity is not active, or there is no activity at all;
//   "extend"  - a higher-priority activity popup is open and still timing: keep it and restart its timer;
//   "show"    - show the new activity's popup.
// s: { requestedExists, requestedActive, hasActivity, activityPopupOpen, popupTimerRunning, nextPriority, shownPriority }
function bumpDecision(s) {
    if (s.requestedExists && !s.requestedActive)
        return "ignore";
    if (!s.hasActivity)
        return "ignore";
    if (s.activityPopupOpen && s.popupTimerRunning && s.nextPriority < s.shownPriority)
        return "extend";
    return "show";
}

// Which model row an activity reads: the first notification row for notices, the first job for jobs, otherwise a job
// before a notification, otherwise row 0. Row numbers are -1 when there is none.
function rowFor(mode, noticeRow, jobRow) {
    if (mode === "notice" && noticeRow >= 0)
        return noticeRow;
    if (mode === "job" && jobRow >= 0)
        return jobRow;
    if (jobRow >= 0)
        return jobRow;
    return noticeRow >= 0 ? noticeRow : 0;
}
