.pragma library
.import "Agents.js" as Agents

// The Claude Code widget (D-60): budget and outcomes, never Live's progress. Pure: the view turns these facts into text
// with Strings.qml. Attention ("Needs your OK") is the one thing it shares with Live.
const RECENT_CAP = 5;
const SPEND_CAP = 200;

function live(sessions) {
    return Agents.order(sessions).filter(s => s.state !== "done");
}

// Windows whose reset has not passed, so a stale ring never shows.
function activeUsage(usage, nowMs) {
    const out = {};
    for (const k of ["fiveHour", "sevenDay"]) {
        if (usage && usage[k] && usage[k].resetsAt > nowMs)
            out[k] = usage[k];
    }
    return out;
}

// A report that lacks a window never clears it: usage is account-wide and a new session has none yet.
function mergeUsage(prev, next) {
    return Object.assign({}, prev || {}, next || {});
}

// sid -> highest cost seen this run, for sessions that cost something (bounded; the oldest entry goes first).
function trackSpend(map, sessions) {
    let out = map;
    for (const s of sessions || []) {
        if (s.costUsd > 0 && !(out[s.id] >= s.costUsd)) {
            if (out === map)
                out = Object.assign({}, map);
            delete out[s.id];
            out[s.id] = s.costUsd;
        }
    }
    const keys = Object.keys(out);
    if (keys.length > SPEND_CAP) {
        out = Object.assign({}, out);
        keys.slice(0, keys.length - SPEND_CAP).forEach(k => delete out[k]);
    }
    return out;
}

function spendTotal(map) {
    const ids = Object.keys(map || {});
    return { "usd": Math.round(ids.reduce((a, k) => a + map[k], 0) * 100) / 100, "sessions": ids.length };
}

// usage: any limit window not yet reset. spend: an API-key setup (cost, and no limits seen this run). neutral: neither.
function mode(activeWindows, sawLimits, spent) {
    if (Object.keys(activeWindows).length > 0)
        return "usage";
    return !sawLimits && spent.usd > 0 ? "spend" : "neutral";
}

// Sessions that finished, newest first, kept in memory only. A session is recorded while it lingers as done; a new prompt
// in it takes it out again (it is live then).
function remember(recent, sessions) {
    let out = recent.filter(r => !sessions.some(s => s.id === r.id && s.state !== "done"));
    for (const s of sessions) {
        if (s.state !== "done")
            continue;
        out = out.filter(r => r.id !== s.id);
        out.unshift({
            "id": s.id, "project": s.project, "state": "done", "lastMessage": s.lastMessage, "linesAdded": s.linesAdded,
            "linesRemoved": s.linesRemoved, "contextPct": s.contextPct, "startedAt": s.startedAt, "endedAt": s.updatedAt,
            "pids": s.pids, "scopeApp": s.scopeApp
        });
    }
    return out.sort((a, b) => b.endedAt - a.endedAt).slice(0, RECENT_CAP);
}

// A row's context bar only shows once the window is nearly full: warn above 80%, critical above 90%, else none.
function contextLevel(pct) {
    if (typeof pct !== "number" || !(pct === pct))
        return "none";
    return pct > 90 ? "critical" : pct > 80 ? "warn" : "none";
}

function minutesAgo(r, nowMs) {
    return Math.max(1, Math.floor((nowMs - r.endedAt) / 60000));
}

// The 1x1 face. m: { usage (windows, not yet filtered), sawLimits, spend (the map), sessions, recent }.
// -> { mode, resting, attention, hero, detail, peek, target, moon } with kinds the view turns into text:
//   hero:   ring {pct} | cost {usd} | count {n} | moon
//   detail: limit {window, resetsAt} | attention {n} | caughtUp | costSessions {n} | project {name} | none
//   side:   [{ window, pct }] shown muted at the top right while resting with usage known | null
//   peek:   week {pct, resetsAt} (while running) | wants {action, text} | last {project, minutes} | null
function face(m, nowMs) {
    const active = activeUsage(m.usage, nowMs);
    const spent = spendTotal(m.spend);
    const md = mode(active, m.sawLimits, spent);
    const run = live(m.sessions);
    const waiting = run.filter(s => s.state === "waiting");
    const resting = run.length === 0;
    const win = active.fiveHour ? "fiveHour" : "sevenDay";
    const out = { "mode": md, "resting": resting, "attention": waiting.length, "moon": false, "peek": null, "side": null, "target": null };

    if (md === "usage")
        out.hero = resting ? { "kind": "moon" } : { "kind": "ring", "pct": active[win].pct };
    else if (md === "spend")
        out.hero = { "kind": "cost", "usd": spent.usd };
    else
        out.hero = resting ? { "kind": "moon" } : { "kind": "count", "n": run.length };

    if (waiting.length > 0) {
        out.detail = { "kind": "attention", "n": waiting.length };
        out.peek = { "kind": "wants", "action": waiting[0].waitingAction, "text": Agents.elide(waiting[0].waitingCommand, 60) };
    } else if (resting) {
        out.detail = { "kind": "caughtUp" };
        if (md === "usage")
            out.side = ["fiveHour", "sevenDay"].filter(k => active[k]).map(k => ({ "window": k, "pct": active[k].pct }));
        if (m.recent.length > 0)
            out.peek = { "kind": "last", "project": m.recent[0].project, "minutes": minutesAgo(m.recent[0], nowMs) };
    } else if (md === "usage") {
        out.detail = { "kind": "limit", "window": win, "resetsAt": active[win].resetsAt };
        if (active.fiveHour && active.sevenDay)
            out.peek = { "kind": "week", "pct": active.sevenDay.pct, "resetsAt": active.sevenDay.resetsAt };
    } else if (md === "spend") {
        out.detail = { "kind": "costSessions", "n": spent.sessions };
    } else {
        out.detail = { "kind": "project", "name": run[0].project };
    }
    out.moon = resting && out.hero.kind !== "moon";
    // The session a click raises: the waiting one, else the most recent live one; nothing when none runs.
    out.target = waiting.length > 0 ? waiting[0].id : run.length > 0 ? run[0].id : null;
    return out;
}

// 2x1 rows: live first (waiting, then working), then the recent ones that are not live. A row carries facts only.
function rows(sessions, recent) {
    const run = live(sessions);
    const ids = new Set(run.map(s => s.id));
    const mk = s => ({ "id": s.id, "state": s.state, "project": s.project, "message": s.state === "done" ? s.lastMessage : "",
        "action": s.action || "", "target": s.target || "", "added": s.linesAdded, "removed": s.linesRemoved, "context": s.contextPct, "level": contextLevel(s.contextPct),
        "wants": s.state === "waiting" ? Agents.elide(s.waitingCommand, 60) : "", "wantsAction": s.waitingAction || "" });
    return run.map(mk).concat(recent.filter(r => !ids.has(r.id)).map(mk));
}

// id -> row, for looking up the facts of a slot's session.
function byId(list) {
    const out = {};
    list.forEach(r => out[r.id] = r);
    return out;
}

// Which two sessions the 2x1 shows, and where (D-60). Sticky: state in, state out, so activity alone never re-shuffles.
// prev: { slots: [id|null, id|null], waitSince: { id: ms } }. A row changes only when its session ends (the most recent
// hidden live one takes the slot) or a hidden session starts waiting (it replaces a quiet row, a finished one first, else the
// one quiet longest). Both rows waiting: a third waiter gets no row (the left block counts it), and the longer wait is
// always on top, whatever caused the order. A working row never moves, and a lone waiting row stays where it is.
const SLOTS = 2;

function assign(prev, sessions, recent) {
    const run = live(sessions);
    const liveBy = {};
    run.forEach(s => liveBy[s.id] = s);
    const doneBy = {};
    (recent || []).forEach(r => doneBy[r.id] = r);
    const before = (prev && prev.waitSince) || {};
    const waitSince = {};
    run.filter(s => s.state === "waiting").forEach(s => waitSince[s.id] = before[s.id] ?? s.updatedAt);
    const waiting = id => id in waitSince;
    const slots = [];
    for (let i = 0; i < SLOTS; ++i) {
        const id = prev && prev.slots ? prev.slots[i] : null;
        slots.push(id && (id in liveBy || id in doneBy) ? id : null);
    }
    const hidden = () => run.filter(s => !slots.includes(s.id));
    const newest = (a, b) => b.startedAt - a.startedAt;
    for (let i = 0; i < SLOTS; ++i) {
        if (slots[i] === null || !(slots[i] in liveBy)) {
            const h = hidden().sort(newest)[0];
            if (h)
                slots[i] = h.id;
        }
    }
    for (let i = 0; i < SLOTS; ++i) {
        if (slots[i] === null) {
            const r = (recent || []).find(x => !slots.includes(x.id));
            if (r)
                slots[i] = r.id;
        }
    }
    for (const w of hidden().filter(s => waiting(s.id)).sort((a, b) => waitSince[a.id] - waitSince[b.id])) {
        const quiet = [0, 1].filter(i => slots[i] !== null && !waiting(slots[i]));
        if (quiet.length === 0)
            break;
        const finished = quiet.filter(i => !(slots[i] in liveBy));
        const pool = finished.length > 0 ? finished : quiet;
        const at = pool.reduce((best, i) => liveBy[slots[i]]?.updatedAt < liveBy[slots[best]]?.updatedAt ? i : best, pool[0]);
        slots[at] = w.id;
    }
    if (slots[0] !== null && slots[1] !== null && waiting(slots[0]) && waiting(slots[1]) && waitSince[slots[0]] > waitSince[slots[1]])
        slots.reverse();
    return { "slots": slots, "waitSince": waitSince };
}

// A row's content height: the name line, the context bar (only when the context is nearly full) and the accent line.
function contentHeight(row, lineH, hairline, accentH, gap) {
    return lineH + (row.level !== "none" ? gap + hairline : 0) + (row.state === "waiting" ? gap + accentH : 0);
}

// Slot heights that fill `span` with `gap` between them: each is its content plus the same padding above and below, so a row
// with one more line gets a taller slot and every highlight looks alike. With no room left the padding is zero.
function slotHeights(span, gap, contents) {
    const n = contents.length;
    if (n === 0)
        return [];
    const free = span - gap * (n - 1) - contents.reduce((a, c) => a + c, 0);
    const pad = Math.max(0, free / (2 * n));
    return contents.map(c => c + 2 * pad);
}

// The slots' y and height inside a tile `height` tall: `edge` from its top and bottom (the divider's own ends), `between` apart
// (the highlight's inset, D-61), each as tall as its row's content needs. rows: the facts of the shown sessions, top to bottom.
function layout(rows, height, edge, between, lineH, hairline, gap) {
    const heights = slotHeights(height - 2 * edge, between, rows.map(r => contentHeight(r, lineH, hairline, lineH, gap)));
    const tops = [];
    let y = edge;
    for (const h of heights) {
        tops.push(y);
        y += h + between;
    }
    return { "tops": tops, "heights": heights };
}
