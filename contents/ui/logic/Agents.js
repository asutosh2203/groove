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
            "startedAt": count(s.startedAt) * 1000,
            "updatedAt": count(s.updatedAt) * 1000,
            "lastMessage": text(s.lastMessage, 120)
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

// Whole minutes since the session's run started; never below 1, the island shows minutes only.
function minutes(s, nowMs) {
    return Math.max(1, Math.floor((nowMs - s.startedAt) / 60000));
}

function elide(str, max) {
    const t = String(str || "");
    return t.length <= max ? t : t.slice(0, Math.max(0, max - 1)).trimEnd() + "…";
}

// What the closed capsule says (D-38, job priority): the project and "done of total" when there is a task list, else the
// elapsed minutes. The caller formats it.
function compactParts(s, nowMs) {
    return { "project": s.project, "progress": hasTasks(s) ? { "done": s.done, "total": s.total } : null, "minutes": minutes(s, nowMs) };
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
