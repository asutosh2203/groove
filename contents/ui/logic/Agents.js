.pragma library
.import "AppMatch.js" as AppMatch

// Agent sessions (D-57): parsing the aggregator's snapshot, ordering, the compact-capsule parts, and finding the window
// that hosts a session. Pure; translated text and colours stay with the callers (Strings.qml, Tokens.js).
const STATES = ["working", "waiting", "done"];
const ACTIONS = ["edit", "run", "read", "search", "other"];
const RANK = { "waiting": 0, "working": 1, "done": 2 };

function text(v, cap) {
    return v === null || v === undefined ? "" : String(v).slice(0, cap);
}

function count(v) {
    const n = Math.floor(Number(v));
    return isFinite(n) && n > 0 ? n : 0;
}

// 0..100 as a whole number, or null when unknown (null early in a session and after /compact: no bar then).
function percent(v) {
    const n = v === null || v === undefined ? NaN : Math.round(Number(v));
    return isFinite(n) ? Math.max(0, Math.min(100, n)) : null;
}

const MAX_SUBAGENTS = 16;
// The command timer appears only for a command that has run this long (W2.1, D-58).
const CLOCK_AFTER_SECONDS = 10;

// { total (s), startedAt (s) } -> { total, startedAt (ms) }, or null for anything that is not a usable countdown.
function countdown(c) {
    const total = c ? Number(c.total) : 0;
    const at = c ? Number(c.startedAt) : 0;
    return total > 0 && at > 0 ? { "total": total, "startedAt": Math.round(at * 1000) } : null;
}

function money(v) {
    const n = Number(v);
    return isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : 0;
}

// The account-wide limit windows of a snapshot (D-60) -> { fiveHour, sevenDay } with resetsAt in ms; a missing or malformed
// window is simply absent, never a reason to clear one already known.
function parseUsage(json) {
    let snap;
    try {
        snap = JSON.parse(json);
    } catch (e) {
        return {};
    }
    const out = {};
    const u = snap && snap.v === 1 && snap.usage && typeof snap.usage === "object" ? snap.usage : {};
    for (const k of ["fiveHour", "sevenDay"]) {
        const pct = u[k] ? percent(u[k].pct) : null;
        const at = u[k] ? Number(u[k].resetsAt) : 0;
        if (pct !== null && at > 0)
            out[k] = { "pct": pct, "resetsAt": Math.round(at * 1000), "at": u[k].at > 0 ? Math.round(Number(u[k].at) * 1000) : 0 };
    }
    return out;
}

// The windows as kept in the plasmoid config (numbers only: pct, reset and report time, in ms) and back. A stored window
// that is malformed or already past its reset is dropped on load.
function serializeUsage(usage) {
    const out = {};
    for (const k of ["fiveHour", "sevenDay"]) {
        if (usage && usage[k])
            out[k] = { "pct": usage[k].pct, "resetsAt": usage[k].resetsAt, "at": usage[k].at || 0 };
    }
    return JSON.stringify({ "v": 1, "usage": out });
}

function parseStoredUsage(json, nowMs) {
    let stored;
    try {
        stored = JSON.parse(json);
    } catch (e) {
        return {};
    }
    const u = stored && stored.v === 1 && stored.usage && typeof stored.usage === "object" ? stored.usage : {};
    const out = {};
    for (const k of ["fiveHour", "sevenDay"]) {
        const pct = u[k] ? percent(u[k].pct) : null;
        const resetsAt = u[k] ? Number(u[k].resetsAt) : 0;
        if (pct !== null && resetsAt > nowMs)
            out[k] = { "pct": pct, "resetsAt": resetsAt, "at": u[k].at > 0 ? Number(u[k].at) : 0 };
    }
    return out;
}

// The Agents1 snapshot JSON -> [session]. Anything unexpected (wrong version, bad JSON, a malformed entry) is dropped.
function parse(json) {
    let snap;
    try {
        snap = JSON.parse(json);
    } catch (e) {
        return [];
    }
    if (!snap || snap.v !== 1 || !Array.isArray(snap.sessions))
        return [];
    const out = [];
    for (const s of snap.sessions) {
        if (!s || !s.id || STATES.indexOf(s.state) < 0)
            continue;
        out.push({
            "id": text(s.id, 128),
            "agent": text(s.agent, 64),
            "name": text(s.name, 64),
            "project": text(s.project, 80) || "project",
            "pids": (Array.isArray(s.pids) ? s.pids : []).map(Number).filter(p => p > 1).slice(0, 32),
            "scopeApp": text(s.scopeApp, 128),
            "state": s.state,
            "task": text(s.task, 120),
            "done": count(s.done),
            "total": count(s.total),
            "action": ACTIONS.indexOf(s.action) >= 0 ? s.action : "",
            "target": text(s.target, 60),
            "waitingCommand": text(s.waitingCommand, 120),
            "waitingAction": ACTIONS.indexOf(s.waitingAction) >= 0 ? s.waitingAction : "",
            "startedAt": count(s.startedAt) * 1000,
            "updatedAt": count(s.updatedAt) * 1000,
            "lastMessage": text(s.lastMessage, 120),
            "contextPct": percent(s.contextPct),
            "costUsd": money(s.costUsd),
            "linesAdded": count(s.linesAdded),
            "linesRemoved": count(s.linesRemoved),
            "toolStartedAt": Math.round(Number(s.toolStartedAt) * 1000) || 0,
            "countdown": countdown(s.countdown),
            "subagents": (Array.isArray(s.subagents) ? s.subagents : []).filter(a => a && a.id).slice(0, MAX_SUBAGENTS).map(a => ({ "id": text(a.id, 64), "type": text(a.type, 40) }))
        });
    }
    return out;
}

// Waiting first (it needs you), then working, then done; newest first within a state, like jobs.
function order(sessions) {
    return (sessions || []).slice().sort((a, b) => RANK[a.state] - RANK[b.state] || b.startedAt - a.startedAt);
}

function hasTasks(s) {
    return s.total > 0;
}

// The working subtitle's detail after the agent's name (the name always leads, D-57): the current task when there is a
// task list, else the app hosting the session.
function subtitleDetail(s, host) {
    return hasTasks(s) && s.task ? s.task : String(host || "");
}

// Whole minutes the run took so far (a finished run stopped at its last update); never below 1, the island shows minutes only.
function minutes(s, nowMs) {
    return Math.max(1, Math.floor(((s.state === "done" ? s.updatedAt : nowMs) - s.startedAt) / 60000));
}

function elide(str, max) {
    const t = String(str || "");
    return t.length <= max ? t : t.slice(0, Math.max(0, max - 1)).trimEnd() + "…";
}

// The 0..1 value of the determinate bar.
function progress(s) {
    return hasTasks(s) ? Math.min(1, s.done / s.total) : 0;
}

// The accent of an agent (D-45: only the waiting state uses it); unknown agents get the neutral fallback.
function accentFor(agent, table, fallback) {
    return table && Object.prototype.hasOwnProperty.call(table, agent) ? table[agent] : fallback;
}

// The first segment test of window titles: "file - project - Visual Studio Code", "~ : zsh — Konsole".
function titleMatches(title, project) {
    const want = String(project || "").trim().toLowerCase();
    if (!want)
        return false;
    return String(title || "").split(/\s[-—–|:]\s/).some(seg => seg.trim().toLowerCase() === want);
}

function newest(tasks, idxs) {
    return idxs.reduce((best, i) => (tasks[i].lastActivated || 0) > (tasks[best].lastActivated || 0) ? i : best, idxs[0]);
}

// Several windows qualify (one editor process, many windows): the one titled with the project, else the most recently
// activated.
function pick(session, tasks, idxs) {
    if (idxs.length === 1)
        return idxs[0];
    const titled = idxs.filter(i => titleMatches(tasks[i].title, session.project));
    return newest(tasks, titled.length > 0 ? titled : idxs);
}

// The window hosting a session, never a guess (D-57). `tasks`: [{ pid, appId, launcherUrl, title, isWindow,
// lastActivated }]. 1: a window whose process is in the session's process chain; 2: a window of the systemd scope's app id;
// otherwise -1, and the session is not clickable.
function findWindow(session, tasks) {
    const list = tasks || [];
    const windows = [];
    for (let i = 0; i < list.length; ++i) {
        if (list[i] && list[i].isWindow !== false)
            windows.push(i);
    }
    const byPid = windows.filter(i => list[i].pid > 1 && session.pids.indexOf(Number(list[i].pid)) >= 0);
    if (byPid.length > 0)
        return pick(session, list, byPid);
    if (!session.scopeApp)
        return -1;
    const byApp = windows.filter(i => AppMatch.findTask(session.scopeApp, [list[i]]) === 0);
    return byApp.length > 0 ? pick(session, list, byApp) : -1;
}

// ---- Richer tiles (D-58): one bar, one clock ----

// Seconds left of an exact-sleep countdown, never below 0 (it holds at 0 until the tool finishes); -1 when there is none.
function countdownLeft(s, nowMs) {
    return s.countdown ? Math.max(0, s.countdown.total - (nowMs - s.countdown.startedAt) / 1000) : -1;
}

// A countdown that has not run out: it owns the bar.
function counting(s, nowMs) {
    return s.state === "working" && countdownLeft(s, nowMs) > 0;
}

// Seconds the current command has run, or -1 when none runs or it has not reached the threshold yet.
function commandSeconds(s, nowMs) {
    if (s.state !== "working" || !(s.toolStartedAt > 0))
        return -1;
    const sec = Math.floor((nowMs - s.toolStartedAt) / 1000);
    return sec >= CLOCK_AFTER_SECONDS ? sec : -1;
}

// m:ss, or h:mm:ss from an hour.
function formatClock(sec) {
    const t = Math.max(0, Math.floor(sec));
    const h = Math.floor(t / 3600);
    const m = Math.floor(t % 3600 / 60);
    const ss = String(t % 60).padStart(2, "0");
    return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
}

// The only clock on a tile, in priority order: { kind: "countdown", text } | { kind: "command", text } |
// { kind: "session", minutes } | { kind: "none" } (waiting and done show none).
function clock(s, nowMs) {
    if (s.state !== "working")
        return { "kind": "none" };
    if (s.countdown)
        return { "kind": "countdown", "text": formatClock(Math.ceil(countdownLeft(s, nowMs))) };
    const cmd = commandSeconds(s, nowMs);
    return cmd >= 0 ? { "kind": "command", "text": formatClock(cmd) } : { "kind": "session", "minutes": minutes(s, nowMs) };
}

// The bar's source, in priority order: "countdown" while it counts, then "tasks", else "none".
function barMode(s, nowMs) {
    if (counting(s, nowMs))
        return "countdown";
    return hasTasks(s) ? "tasks" : "none";
}

// 0..1 of the bar for the current mode.
function barValue(s, nowMs) {
    return barMode(s, nowMs) === "countdown" ? Math.min(1, 1 - countdownLeft(s, nowMs) / s.countdown.total) : progress(s);
}

// A tile needs a seconds clock only while one is moving: a countdown that has not run out, or a command timer (also
// before the 10 s threshold, so it can appear). The service runs its 1 Hz timer only then, and only while the deck shows.
function needsSeconds(s, nowMs) {
    return s.state === "working" && (counting(s, nowMs) || !s.countdown && s.toolStartedAt > 0);
}

// "general-purpose" -> "General purpose".
function humanType(type) {
    const t = String(type || "").replace(/[-_]+/g, " ").trim();
    return t ? t.charAt(0).toUpperCase() + t.slice(1) : "";
}

// { count, names } for "2 subagents · Explore, Plan"; names are humanised, distinct, in start order (empty when no type is known).
function subagentSummary(s) {
    const names = [];
    for (const a of s.subagents || []) {
        const n = humanType(a.type);
        if (n && names.indexOf(n) < 0)
            names.push(n);
    }
    return { "count": (s.subagents || []).length, "names": names };
}

// What the bottom line's left side says, in priority order: "waiting", "countdown", "subagents", else "action".
function lineKind(s, nowMs) {
    if (s.state === "waiting")
        return "waiting";
    if (s.state === "done")
        return "done";
    if (s.countdown)
        return "countdown";
    return (s.subagents || []).length > 0 ? "subagents" : "action";
}

// The closed capsule, in priority order (never seconds): waiting, countdown ("N min left", minutes rounded up, so it
// holds the minute until it passes), task list, subagents, else the action verb. `nowMs` is the service's coarse clock.
function compact(s, nowMs) {
    const out = { "project": s.project, "mode": "verb", "kind": s.action || "other" };
    if (s.state === "waiting") {
        out.mode = "waiting";
    } else if (counting(s, nowMs)) {
        out.mode = "countdown";
        out.minutesLeft = Math.max(1, Math.ceil(countdownLeft(s, nowMs) / 60));
    } else if (hasTasks(s)) {
        out.mode = "tasks";
        out.done = s.done;
        out.total = s.total;
    } else if ((s.subagents || []).length > 0) {
        out.mode = "subagents";
        out.count = s.subagents.length;
    }
    return out;
}
