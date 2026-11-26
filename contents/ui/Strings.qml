pragma ComponentBehavior: Bound

import QtQuick
import "logic/Utils.js" as Utils

// Every user-visible string that is chosen in code, in one place. The services and the logic modules never translate:
// they return which line applies ("off", "noAdapter", ...) and this file turns that into the user's language.
//
// i18n() and i18np() are Plasma's global translation functions, supplied to the QML engine at runtime (KLocalizedContext).
// The linter cannot see them, so each call is reported as an unqualified access: a false positive that cannot be
// qualified. The suppression below is limited to this one block, so the rest of the codebase keeps full checking. One
// instance per island (no singleton); main.qml exposes it as `strings`.
QtObject {
    // qmllint disable unqualified
    readonly property string appTitle: i18n("Kove")
    readonly property string idleTitle: i18n("Widgets")
    readonly property string idleSubtitle: i18n("Click to cycle pages, double-click for Control Center")
    readonly property string notificationFallback: i18n("Notification")
    readonly property string replySend: i18n("Send reply")
    readonly property string replyFailed: i18n("Couldn't send: the notification is gone")

    function replyPlaceholder(sender) {
        return i18n("Reply to %1…", sender);
    }
    readonly property string jobCollapse: i18n("Collapse")
    readonly property string deckLive: i18n("Live")
    readonly property string deckControlCenter: i18n("Control Center")

    // A preset page's name for screen readers: its id until presets have names.
    function deckPage(id) {
        return i18n("Page %1", id);
    }

    // The preset editor (D-56).
    readonly property string editDone: i18n("Done")
    readonly property string editCancel: i18n("Cancel")
    readonly property string editBack: i18n("Back")
    readonly property string editReset: i18n("Reset draft to default")
    readonly property string editWidgets: i18n("Widgets")
    readonly property string editAddWidget: i18n("Add widget")
    readonly property string editWontFit: i18n("won't fit")
    readonly property string editDoesntFit: i18n("Doesn't fit")
    readonly property string editRemoveWidget: i18n("Remove widget")
    readonly property string editGridHint: i18n("Click a widget for its settings · drag to reorder")
    readonly property string editDiscardTitle: i18n("Discard your changes?")
    readonly property string editKeep: i18n("Keep editing")
    readonly property string editDiscard: i18n("Discard")
    readonly property string editRestored: i18n("Unsaved changes restored")
    readonly property string editDevPresets: i18n("Dev presets active: preset changes won't be saved")
    readonly property string editLocationPlaceholder: i18n("Search for a city")
    readonly property string editSearching: i18n("Searching…")
    readonly property string editSearchShort: i18n("Type at least two characters.")
    readonly property string editSearchFailed: i18n("Search failed. Check your connection and try again.")
    readonly property string editSearchNone: i18n("No matching places found.")
    readonly property string editSettingsOf: i18n("Settings")
    readonly property string editSize: i18n("Size")
    readonly property string editOptionMissing: i18n("Not found")
    readonly property string editPreview: i18n("Live preview")
    readonly property string editGear: i18n("Control Center tiles")

    readonly property string editLocalTime: i18n("Local time")
    readonly property string editZonePlaceholder: i18n("Search for a city")
    readonly property string editZoneIdPlaceholder: i18n("Time zone id, e.g. Europe/Lisbon")
    readonly property string editZoneUnknown: i18n("Unknown time zone")
    readonly property string editNew: i18n("New")
    readonly property string editInCycle: i18n("Shown in the deck")
    readonly property string editOutOfCycle: i18n("Hidden from the deck")
    readonly property string editRemovePreset: i18n("Remove preset")

    function editPresetCount(n, max) {
        return i18n("%1 of %2 presets", n, max);
    }

    function pageTypeName(type) {
        return type === "wide" ? i18n("Wide") : type === "tall" ? i18n("Tall") : i18n("Small");
    }

    function spanName(span) {
        return span === "4x1" ? i18n("Wide") : span === "2x1" ? i18n("Medium") : i18n("Small");
    }

    function spanOnly(span) {
        return i18n("%1 only", spanName(span));
    }

    // Why a change or a save was refused.
    function editHint(reason) {
        switch (reason) {
        case "nofit":
            return i18n("Doesn't fit this page");
        case "cap":
            return i18n("Presets are limited to 3");
        case "unreadable":
            return i18n("Saved presets can't be read, so they can't be changed");
        case "problem":
            return i18n("A preset doesn't fit its page; fix it first");
        }
        return "";
    }
    readonly property string previous: i18n("Previous")
    readonly property string pause: i18n("Pause")
    readonly property string play: i18n("Play")
    readonly property string next: i18n("Next")
    readonly property string themeSettings: i18n("Theme settings")
    readonly property string themeSettingsDetail: i18n("Choose light and dark themes in System Settings")
    readonly property string themeSettingsFooter: i18n("Click to open")

    // The current colour scheme, read only (D-40): the widget never switches it.
    function colorSchemeName(dark) {
        return dark ? i18n("Dark") : i18n("Light");
    }

    function notificationStatus(count) {
        if (count <= 0)
            return i18n("Quiet");
        if (count === 1)
            return i18n("1 notification");
        return i18np("%1 notification", "%1 notifications", count);
    }

    // The job's own title, or "Working" when it has none; more than one file adds the count.
    function jobTitle(title, files) {
        const base = title.length > 0 ? title : i18n("Working");
        return files > 1 ? base + " " + i18np("%1 file", "%1 files", files) : base;
    }

    function jobSubtitle(destination, fallback) {
        return destination.length > 0 ? i18n("to %1", destination) : fallback;
    }

    function duration(seconds) {
        if (seconds < 60)
            return i18n("%1 s", seconds);
        if (seconds < 3600)
            return i18n("%1 min", Math.ceil(seconds / 60));
        return i18n("%1 h %2 min", Math.floor(seconds / 3600), Math.floor(seconds % 3600 / 60));
    }

    // meta: Jobs.meta
    function jobMeta(meta) {
        if (meta.kind === "paused")
            return i18n("Paused");
        if (meta.kind !== "speed")
            return "";
        const speed = Utils.formatByteSize(meta.speed) + "/s";
        return meta.remaining >= 0 ? speed + " · " + i18n("%1 left", duration(meta.remaining)) : speed;
    }

    // The speed half of a job tile's meta line ("12.4 MB/s", or "Paused").
    function jobSpeed(meta) {
        if (meta.kind === "paused")
            return i18n("Paused");
        return meta.kind === "speed" ? Utils.formatByteSize(meta.speed) + "/s" : "";
    }

    // "63% · 3 min left", leaving out whatever is unknown (percent -1, remaining -1).
    function jobProgress(percent, remaining) {
        const parts = [];
        if (percent >= 0)
            parts.push(percent + "%");
        if (remaining >= 0)
            parts.push(i18n("%1 left", duration(remaining)));
        return parts.join(" · ");
    }

    // Agent sessions (D-57). The aggregator sends facts (an action and a short target); the wording is chosen here.
    readonly property string agentNeedsOk: i18n("Needs your OK")

    // The tail after the agent's name on a working tile: "· Merge the CC editor", "· Code". Empty detail, no tail.
    function agentSubtitleTail(detail) {
        return detail ? i18n("· %1", detail) : "";
    }

    function agentMinutes(minutes) {
        return i18n("%1 min", minutes);
    }

    function agentDone(minutes) {
        return i18n("Done · %1 min", minutes);
    }

    function agentProgress(done, total) {
        return i18n("%1 of %2", done, total);
    }

    // The closed capsule's tail after the project name and its dot (Agents.compact): "4 min left" during a countdown (never
    // seconds), "3 of 7", "2 subagents", else the action's kind ("editing").
    function agentCompactTail(c) {
        switch (c.mode) {
        case "countdown":
            return i18n("%1 min left", c.minutesLeft);
        case "tasks":
            return i18n("%1 of %2", c.done, c.total);
        case "subagents":
            return i18np("%1 subagent", "%1 subagents", c.count);
        }
        switch (c.kind) {
        case "edit":
            return i18n("editing");
        case "run":
            return i18n("running");
        case "read":
            return i18n("reading");
        case "search":
            return i18n("searching");
        default:
            return i18n("working");
        }
    }

    // The clock's text during an exact-sleep countdown: "3:12 left".
    function agentClockLeft(clock) {
        return i18n("%1 left", clock);
    }

    // The action line during a countdown: "Waiting · sleep 5m".
    function agentCountdownLine(target) {
        return target ? i18n("Waiting · %1", target) : i18n("Waiting");
    }

    // "2 subagents · Explore, Plan"; with no known types just the count.
    function agentSubagents(summary) {
        const head = i18np("%1 subagent", "%1 subagents", summary.count);
        return summary.names.length > 0 ? i18n("%1 · %2", head, summary.names.join(", ")) : head;
    }

    // What the agent is doing now: "Editing PresetEditor.qml", "Running: npm test…".
    function agentAction(action, target) {
        switch (action) {
        case "edit":
            return target ? i18n("Editing %1", target) : i18n("Editing");
        case "run":
            return target ? i18n("Running: %1…", target) : i18n("Running a command");
        case "read":
            return target ? i18n("Reading %1", target) : i18n("Reading");
        case "search":
            return i18n("Searching");
        default:
            return i18n("Working");
        }
    }

    // The waiting line: a command is "Wants to run: <command>"; anything else already reads as a sentence.
    function agentWants(action, text) {
        return action === "run" ? i18n("Wants to run: %1", text) : text;
    }

    // The Claude Code widget (D-60): budget and outcomes. Times arrive already formatted by the view.
    readonly property string claudeLabel: i18n("Claude Code")
    readonly property string claudeCaughtUp: i18n("All caught up")
    readonly property string claudeNoRecent: i18n("No recent sessions")

    function claudeLimit(weekly, when) {
        return weekly ? i18n("Weekly limit · resets %1", when) : i18n("5h limit · resets %1", when);
    }

    function claudeWeek(pct, when) {
        return i18n("This week %1% · resets %2", pct, when);
    }

    readonly property string claudeTerminalOnly: i18n("Usage comes from terminal sessions")

    // The resting widget's quiet usage lines, short: "5h 34%", "wk 12%".
    function claudeUsageShort(weekly, pct) {
        return weekly ? i18n("wk %1%", pct) : i18n("5h %1%", pct);
    }

    function claudeAttention(n) {
        return i18np("%1 needs your OK", "%1 need your OK", n);
    }

    function claudeRunning(n) {
        return i18n("%1 running", n);
    }

    function claudeCost(usd) {
        return i18n("≈ $%1", usd.toFixed(2));
    }

    function claudeCostSessions(n) {
        return i18np("est. · %1 session", "est. · %1 sessions", n);
    }

    function claudeLast(project, minutes) {
        return i18n("Last: %1 · %2 min ago", project, minutes);
    }

    // A row: the project, then " · message" (the current action when nothing was said yet).
    function claudeRowTail(text) {
        return text ? i18n(" · %1", text) : "";
    }

    function claudeLines(added, removed) {
        return i18n("+%1 −%2", added, removed);
    }

    function claudeNeedsOkLine(text) {
        return text ? i18n("Needs your OK · %1", text) : i18n("Needs your OK");
    }

    // The job list's header noun: "3 copies", or "3 transfers" for mixed kinds (LiveLayout.header).
    function liveHeader(kind, count) {
        switch (kind) {
        case "copy":
            return i18np("%1 copy", "%1 copies", count);
        case "move":
            return i18np("%1 move", "%1 moves", count);
        case "download":
            return i18np("%1 download", "%1 downloads", count);
        case "upload":
            return i18np("%1 upload", "%1 uploads", count);
        case "delete":
            return i18np("%1 deletion", "%1 deletions", count);
        default:
            return i18np("%1 transfer", "%1 transfers", count);
        }
    }

    function wifiTitle(hardwareEnabled, enabled) {
        if (!hardwareEnabled)
            return i18n("Unavailable");
        return enabled ? i18n("On") : i18n("Off");
    }

    // summary: Bluetooth.summary
    function bluetoothSummary(summary) {
        switch (summary.kind) {
        case "noAdapter":
            return i18n("No adapter");
        case "off":
            return i18n("Off");
        case "on":
            return i18n("On");
        case "device":
            return summary.text;
        default:
            return i18np("%1 device", "%1 devices", summary.count);
        }
    }

    // detail: Bluetooth.detail
    function bluetoothDetail(detail) {
        switch (detail.kind) {
        case "unavailable":
            return i18n("Bluetooth adapter unavailable");
        case "radioOff":
            return i18n("Radio disabled");
        case "devices":
        case "adapter":
            return detail.text;
        default:
            return i18n("No connected devices");
        }
    }

    // kind: KdeConnectState.summaryKind
    function kdeConnectSummary(kind, connectedCount) {
        if (kind === "connected")
            return i18np("%1 connected", "%1 connected", connectedCount);
        return kind === "away" ? i18n("Not nearby") : i18n("No devices");
    }

    // kind: SystemControls.profileKind
    function profileTitle(kind) {
        switch (kind) {
        case "performance":
            return i18n("Performance");
        case "saver":
            return i18n("Saver");
        default:
            return i18n("Balanced");
        }
    }

    // kind: SystemControls.batteryKind
    function batteryText(kind, percent) {
        switch (kind) {
        case "ac":
            return i18n("AC");
        case "power":
            return i18n("Power");
        default:
            return percent + "%";
        }
    }

    // Widgets (D-54, D-55): the host's placeholders and the first widgets' words.
    readonly property string widgetUnavailable: i18n("Widget unavailable")
    readonly property string widgetError: i18n("Couldn't load")
    readonly property string widgetSetLocation: i18n("Set a location")
    readonly property string widgetUnknownZone: i18n("Unknown time zone")
    readonly property string today: i18n("Today")
    readonly property string tomorrow: i18n("Tomorrow")
    readonly property string yesterday: i18n("Yesterday")
    readonly property string now: i18n("Now")
    readonly property string sunrise: i18n("Sunrise")
    readonly property string sunset: i18n("Sunset")

    // System Monitor (D-65). Kinds come from Sysmon.js.
    function sysmonLabel(kind) {
        return ({ "cpu": i18n("CPU"), "gpu": i18n("GPU"), "ram": i18n("RAM"), "cpuTemp": i18n("CPU temp"), "gpuTemp": i18n("GPU temp"), "network": i18n("Network"), "disk": i18n("Disk") })[kind] ?? "";
    }

    function sysmonError(kind, reason) {
        return reason === "missing" ? i18n("No %1 sensor", sysmonLabel(kind)) : reason === "removed" ? i18n("Sensor removed") : i18n("Sensor not responding");
    }

    // The tall box's extra line: { key, value } from Sysmon.companion.
    function sysmonCompanion(c) {
        if (!c)
            return "";
        return c.key === "swap" ? i18n("Swap %1", c.value) : c.key === "gpu" && c.name.length > 0 ? i18n("%1 · %2", c.name, c.value) : c.value;
    }

    function sysmonAlert(kind, value, seconds) {
        const subject = ({ "cpu": i18n("CPU"), "cpuTemp": i18n("CPU"), "gpu": i18n("GPU"), "gpuTemp": i18n("GPU"), "ram": i18n("RAM") })[kind] ?? "";
        return seconds >= 90 ? i18n("%1 at %2 for %3 min", subject, value, Math.round(seconds / 60)) : i18n("%1 at %2 for %3 s", subject, value, seconds);
    }

    // Pomodoro (D-64). Kinds come from PomodoroEngine: focus, break, long; plain means a single-phase timer.
    function pomodoroPhase(kind, plain) {
        return plain ? i18n("Timer") : kind === "break" ? i18n("Break") : kind === "long" ? i18n("Long break") : i18n("Focus");
    }
    readonly property string pomodoroReady: i18n("Pomodoro")
    readonly property string pomodoroTimerReady: i18n("Timer")
    readonly property string pomodoroPlay: i18n("Start")
    readonly property string pomodoroPause: i18n("Pause")
    readonly property string pomodoroSkip: i18n("Skip")
    readonly property string pomodoroReset: i18n("Reset")

    function pomodoroRound(round, rounds) {
        return i18n("Round %1 of %2", round, rounds);
    }

    function pomodoroPlainOf(minutes) {
        return i18n("of %1 min", minutes);
    }

    function pomodoroReadyDetail(rounds, focus, brk) {
        return rounds > 1 ? i18n("%1 rounds · %2 / %3", rounds, focus, brk) : i18n("%1 min", focus);
    }

    function pomodoroNextIs(kind) {
        return i18n("%1's next", pomodoroPhase(kind, false));
    }

    readonly property string pomodoroDoneCycle: i18n("Done")

    function pomodoroNext(phase) {
        return phase ? i18n("Next: %1 %2 min", pomodoroPhase(phase.kind, false), Math.round(phase.ms / 60000)) : i18n("Cycle ends");
    }

    function pomodoroNextLong(phase, longAfter) {
        const base = phase ? i18n("%1 %2 min next", pomodoroPhase(phase.kind, false), Math.round(phase.ms / 60000)) : i18n("Cycle ends");
        return longAfter > 0 && phase && phase.kind !== "long" ? i18n("%1 · long after %2", base, longAfter) : base;
    }

    function pomodoroLongAfter(n) {
        return i18n("Long break after %1", n);
    }

    readonly property string pomodoroNoLong: i18n("No long break")

    function pomodoroDone(n) {
        return i18np("%1 done", "%1 done", n);
    }

    function pomodoroNextRound(kind, round, rounds) {
        return i18n("%1 %2 of %3 next", pomodoroPhase(kind, false), round, rounds);
    }

    function pomodoroDuration(minutes) {
        return minutes >= 60 ? (minutes % 60 === 0 ? i18n("%1 h", Math.floor(minutes / 60)) : i18n("%1 h %2 m", Math.floor(minutes / 60), minutes % 60)) : i18n("%1 min", minutes);
    }

    function pomodoroCycle(minutes) {
        return i18n("Cycle · %1", pomodoroDuration(minutes));
    }

    function pomodoroLongAt(time) {
        return i18n("Long break at %1", time);
    }

    // A computed settings line (WidgetNotes.describe).
    function widgetNote(note) {
        if (!note)
            return "";
        return note.plain ? i18n("A plain timer · %1 min", note.roundMinutes) : i18n("Each round %1 min · full cycle %2", note.roundMinutes, pomodoroDuration(note.cycleMinutes));
    }

    // The closed capsule: "Focus · 24 min" (never seconds, D-64), or what a timer waiting for play says.
    function pomodoroCapsule(c, plain) {
        return c.kind === "ended" ? i18n("Start next") : i18n("%1 · %2 min", pomodoroPhase(c.kind, plain), c.minutes);
    }

    // The phase-end notification (PomodoroEngine.alert).
    function pomodoroAlertTitle(a) {
        switch (a.kind) {
        case "focusDone":
            return i18n("Focus done · %1 %2 min", pomodoroPhase(a.nextKind, false).toLowerCase(), a.nextMinutes);
        case "breakOver":
            return i18n("Break over · round %1", a.round);
        case "timerDone":
            return i18n("Timer done");
        }
        return i18n("Cycle complete");
    }

    // unit and n come from WidgetState.age.
    function updatedAgo(unit, n) {
        return unit === "minute" ? i18n("updated %1 min ago", n) : unit === "hour" ? i18n("updated %1 h ago", n) : i18n("updated %1 d ago", n);
    }

    function dayRelation(relation) {
        return relation < 0 ? yesterday : relation > 0 ? tomorrow : today;
    }

    // key comes from WeatherCodes.conditionKey.
    function condition(key) {
        switch (key) {
        case "sunny":
            return i18n("Sunny");
        case "clear":
            return i18n("Clear");
        case "mostlyClear":
            return i18n("Mostly clear");
        case "partlyCloudy":
            return i18n("Partly cloudy");
        case "cloudy":
            return i18n("Cloudy");
        case "fog":
            return i18n("Fog");
        case "drizzle":
            return i18n("Drizzle");
        case "freezingDrizzle":
            return i18n("Freezing drizzle");
        case "rain":
            return i18n("Rain");
        case "freezingRain":
            return i18n("Freezing rain");
        case "snow":
            return i18n("Snow");
        case "showers":
            return i18n("Showers");
        case "snowShowers":
            return i18n("Snow showers");
        case "thunderstorm":
            return i18n("Thunderstorm");
        default:
            return "";
        }
    }

    // The welcome tour (D-69), keyed by the step ids of Tour.js.
    function tourTitle(id) {
        switch (id) {
        case "island":
            return i18n("Your island");
        case "live":
            return i18n("Live activities");
        case "deck":
            return i18n("The deck");
        case "customize":
            return i18n("Make it yours");
        case "gestures":
            return i18n("Gestures and setup");
        default:
            return "";
        }
    }

    function tourBody(id) {
        switch (id) {
        case "island":
            return i18n("Idle, Kove shows the time and weather. Click the time or weather for your calendar and forecast, or anywhere else on the island to open the deck. Choose Notch or Pill in the widget settings.");
        case "live":
            return i18n("Music, notifications, downloads, and Claude Code sessions take over the island while they run. Reply to a message right from its notification when the app offers a reply.");
        case "deck":
            return i18n("The capsule under the island moves between pages. Press and drag across it to scrub. Double-click the island to jump to the Control Center.");
        case "customize":
            return i18n("Click the pencil in the Control Center to add widgets: clocks, weather, Pomodoro, System Monitor, and Claude Code. Arrange up to three pages of your own.");
        case "gestures":
            return i18n("Scroll on the island for volume. Middle-click plays or pauses music. Set your weather city in the widget settings. Claude Code sessions need an optional helper from the Kove repository.");
        default:
            return "";
        }
    }

    function tourCounter(n, total) {
        return i18n("%1 of %2", n, total);
    }

    readonly property string tourRetake: i18n("Show the welcome tour")
    readonly property string tourSkip: i18n("Skip")
    readonly property string tourBack: i18n("Back")
    readonly property string tourNext: i18n("Next")
    readonly property string tourDone: i18n("Done")
    readonly property string tourAddExample: i18n("Add an example page")
    readonly property string tourShowExample: i18n("Show the example page")

    // Why the example page cannot be added, by StarterPresets.status; "" when it can.
    function tourExampleHint(state) {
        switch (state) {
        case "cap":
            return i18n("Your three pages are full");
        case "locked":
            return i18n("Pages are locked by a developer setting");
        case "draft":
            return i18n("Finish your unsaved changes first");
        case "unreadable":
            return i18n("Your saved pages can't be read");
        case "unavailable":
            return i18n("Those widgets aren't available");
        default:
            return "";
        }
    }
    // qmllint enable unqualified
}
