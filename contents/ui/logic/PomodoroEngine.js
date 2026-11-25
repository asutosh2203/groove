.pragma library

// The Pomodoro timer (D-64): a pure, deadline-based state machine. A running phase stores `endsAt` and the remaining time
// is always computed from the clock; pausing stores the remaining time. Nothing decrements a counter, so a stalled
// event loop or a suspend cannot make it drift. Every phase end waits for the user ("ended"); nothing auto-advances.
//
// cfg: { focus, brk, rounds, longBreak } in minutes. state: { status, idx, endsAt, remaining, done }.
//   status "ready"   : idx 0, nothing started
//   status "running" : phases[idx] counts down to endsAt
//   status "paused"  : phases[idx] holds `remaining` ms
//   status "ended"   : phases[idx] has finished or been skipped; play starts phases[idx + 1] (a fresh cycle after the last)
// `done` counts focus phases that ran to their end (skipped ones do not count) and survives a reset.

const MIN = 60000;

function config(settings) {
    return { "focus": settings.focus, "brk": settings["break"], "rounds": settings.rounds, "longBreak": settings.longBreak, "dnd": settings.dnd !== false };
}

// The sequence: focus (then a break) per round; after the last focus the long break if there is one, else the cycle ends.
function phases(cfg) {
    const out = [];
    for (let r = 1; r <= cfg.rounds; ++r) {
        out.push({ "kind": "focus", "round": r, "ms": cfg.focus * MIN });
        if (r < cfg.rounds) {
            if (cfg.brk > 0)
                out.push({ "kind": "break", "round": r, "ms": cfg.brk * MIN });
        } else if (cfg.longBreak > 0) {
            out.push({ "kind": "long", "round": r, "ms": cfg.longBreak * MIN });
        }
    }
    return out;
}

// One phase and nothing else: a plain timer, labelled "Timer" instead of Focus and Break.
function isPlain(cfg) {
    return phases(cfg).length === 1;
}

// Lengths are derived from the settings and never entered, so they cannot disagree.
function derived(cfg) {
    const all = phases(cfg);
    return { "roundMs": (cfg.focus + cfg.brk) * MIN, "cycleMs": all.reduce((sum, p) => sum + p.ms, 0), "phases": all.length, "plain": all.length === 1 };
}

function initial(done) {
    return { "status": "ready", "idx": 0, "endsAt": 0, "remaining": 0, "done": done || 0 };
}

function withState(state, change) {
    return Object.assign({}, state, change);
}

function current(state, cfg) {
    return phases(cfg)[state.idx] || null;
}

// The phase play would start, or null when the cycle is over (running or paused: the one after this; ready: the first).
function next(state, cfg) {
    const all = phases(cfg);
    return state.status === "ready" ? all[0] : all[state.idx + 1] || null;
}

function remainingMs(state, cfg, now) {
    switch (state.status) {
    case "running":
        return Math.max(0, state.endsAt - now);
    case "paused":
        return state.remaining;
    case "ready":
        return phases(cfg)[0].ms;
    }
    return 0;
}

// Starts the phase at `idx` now.
function begin(state, cfg, idx, now) {
    return withState(state, { "status": "running", "idx": idx, "endsAt": now + phases(cfg)[idx].ms, "remaining": 0 });
}

function play(state, cfg, now) {
    switch (state.status) {
    case "ready":
        return begin(state, cfg, 0, now);
    case "paused":
        return withState(state, { "status": "running", "endsAt": now + state.remaining, "remaining": 0 });
    case "ended":
        return begin(state, cfg, state.idx + 1 < phases(cfg).length ? state.idx + 1 : 0, now);
    }
    return state;
}

function pause(state, now) {
    return state.status === "running" ? withState(state, { "status": "paused", "remaining": Math.max(0, state.endsAt - now), "endsAt": 0 }) : state;
}

function toggle(state, cfg, now) {
    return state.status === "running" ? pause(state, now) : play(state, cfg, now);
}

// Ends the current phase now. It is not a completed focus, so `done` stays.
function skip(state) {
    return state.status === "running" || state.status === "paused" ? withState(state, { "status": "ended", "endsAt": 0, "remaining": 0 }) : state;
}

function reset(state) {
    return initial(state.done);
}

// Call when the deadline may have passed. { state, finished }: `finished` is the phase that just ran out, once.
function tick(state, cfg, now) {
    if (state.status !== "running" || now < state.endsAt)
        return { "state": state, "finished": null };
    const phase = current(state, cfg);
    return { "state": withState(state, { "status": "ended", "endsAt": 0, "done": state.done + (phase.kind === "focus" ? 1 : 0) }), "finished": phase };
}

// Phases that have passed (finished or skipped): all before idx, and idx itself once ended.
function passed(state) {
    return state.status === "ready" ? 0 : state.idx + (state.status === "ended" ? 1 : 0);
}

// True once every phase has passed: the cycle is over and play starts a new one.
function cycleOver(state, cfg) {
    return state.status === "ended" && state.idx + 1 >= phases(cfg).length;
}

// Which round the user is in: the running or paused phase's, the next one's when waiting, 1 when ready or over.
function round(state, cfg) {
    const all = phases(cfg);
    if (state.status === "ended")
        return (all[state.idx + 1] || all[state.idx]).round;
    return all[state.idx].round;
}

// One dot per round: "done" once its focus passed, "current" for the round in progress, else "upcoming". After a break the
// next round is the current one.
function dots(state, cfg) {
    const all = phases(cfg);
    const n = passed(state);
    const out = [];
    let foundCurrent = false;
    for (let r = 1; r <= cfg.rounds; ++r) {
        const focusAt = all.findIndex(p => p.kind === "focus" && p.round === r);
        if (focusAt < n)
            out.push("done");
        else if (!foundCurrent) {
            out.push("current");
            foundCurrent = true;
        } else
            out.push("upcoming");
    }
    return out;
}

// How much of each round's dot is filled with light (D-64): 0 to 1 over that round's focus phase, so a finished round is 1,
// the round in progress is its focus fraction and a later one 0. Breaks change nothing. stepMs rounds the elapsed time down
// (the widget redraws every ~15 s); 0 is exact.
function dotFills(state, cfg, now, stepMs) {
    const all = phases(cfg);
    const n = passed(state);
    const running = state.status === "running" || state.status === "paused";
    const out = [];
    for (let r = 1; r <= cfg.rounds; ++r) {
        const at = all.findIndex(p => p.kind === "focus" && p.round === r);
        if (at < n)
            out.push(1);
        else if (at === n && running) {
            const elapsed = all[at].ms - remainingMs(state, cfg, now);
            const stepped = stepMs > 0 ? Math.floor(elapsed / stepMs) * stepMs : elapsed;
            out.push(Math.min(1, Math.max(0, stepped / all[at].ms)));
        } else
            out.push(0);
    }
    return out;
}

// The cycle as a timeline: segments sized by their real length. fill is 0..1; "current" fills while it runs.
function timeline(state, cfg, now) {
    const all = phases(cfg);
    const n = passed(state);
    return all.map((p, i) => {
        if (i < n)
            return { "kind": p.kind, "ms": p.ms, "state": "done", "fill": 1 };
        if (i === n && (state.status === "running" || state.status === "paused"))
            return { "kind": p.kind, "ms": p.ms, "state": "current", "fill": Math.min(1, Math.max(0, 1 - remainingMs(state, cfg, now) / p.ms)) };
        return { "kind": p.kind, "ms": p.ms, "state": "future", "fill": 0 };
    });
}

// Elapsed share of the running phase, 0..1 (the ring).
function progress(state, cfg, now) {
    const p = current(state, cfg);
    if (!p || state.status === "ready" || state.status === "ended")
        return 0;
    return Math.min(1, Math.max(0, 1 - remainingMs(state, cfg, now) / p.ms));
}

// Where the closed capsule ranks this timer (D-64, amends D-38): a running focus above media, a running break or a timer
// waiting for play below it. A timer waiting for play adds a dot. Ready and paused timers are not on the capsule.
// Returns null, or { tier: "focus"|"break", dot, minutes } (minutes: whole minutes left, rounded up, never seconds).
function capsule(state, cfg, now) {
    if (state.status === "running") {
        const phase = current(state, cfg);
        return { "tier": phase.kind === "focus" ? "focus" : "break", "dot": false, "minutes": Math.ceil(remainingMs(state, cfg, now) / MIN), "kind": phase.kind };
    }
    if (state.status === "ended")
        return { "tier": "break", "dot": true, "minutes": 0, "kind": "ended" };
    return null;
}

// The timers a surface should show, most urgent first: waiting for play, then running by soonest end, then paused.
// timers: [{ pid, state }].
function order(timers) {
    const rank = t => t.state.status === "ended" ? 0 : t.state.status === "running" ? 1 : t.state.status === "paused" ? 2 : 3;
    return timers.slice().sort((a, b) => rank(a) - rank(b) || (a.state.endsAt - b.state.endsAt));
}

// The one timer the capsule and the Live glyph speak for: the first running one by soonest end, else a waiting one.
function lead(timers) {
    const first = order(timers).find(t => t.state.status === "running" || t.state.status === "ended");
    return first || null;
}

// What the notification says when a phase ends (D-64). Returns a description; Strings.qml turns it into the user's language.
// finished: the phase that ran out. { kind: "focusDone"|"breakOver"|"timerDone"|"cycleDone", nextKind, nextMinutes, round }
function alert(finished, state, cfg) {
    const all = phases(cfg);
    const upcoming = all[state.idx + 1] || null;
    if (all.length === 1)
        return { "kind": "timerDone", "nextKind": "", "nextMinutes": 0, "round": 1 };
    if (!upcoming)
        return { "kind": "cycleDone", "nextKind": "", "nextMinutes": 0, "round": finished.round };
    return {
        "kind": finished.kind === "focus" ? "focusDone" : "breakOver",
        "nextKind": upcoming.kind,
        "nextMinutes": Math.round(upcoming.ms / MIN),
        "round": upcoming.round
    };
}

// m:ss for the ring (rounded up, so it reads 0:00 only at the end), h:mm:ss from 100 minutes.
function mmss(ms) {
    const total = Math.ceil(Math.max(0, ms) / 1000);
    const h = Math.floor(total / 3600);
    const m = Math.floor(total % 3600 / 60);
    const sec = total % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return h > 0 && total >= 6000 ? h + ":" + two(m) + ":" + two(sec) : Math.floor(total / 60) + ":" + two(sec);
}

// When the long break starts (ms), assuming no pauses, or -1 when there is none or it has passed.
function longBreakAt(state, cfg, now) {
    const all = phases(cfg);
    const at = all.findIndex(p => p.kind === "long");
    const n = passed(state);
    if (at < 0 || at < n)
        return -1;
    let t = state.status === "running" || state.status === "paused" ? now + remainingMs(state, cfg, now) : now;
    for (let i = state.status === "running" || state.status === "paused" ? n + 1 : n; i < at; ++i)
        t += all[i].ms;
    return t;
}

// Everything a view draws, at `now`: one plain object so a binding re-evaluates once per tick.
function snapshot(state, cfg, now) {
    const all = phases(cfg);
    const phase = current(state, cfg);
    const upcoming = next(state, cfg);
    const plain = all.length === 1;
    const over = cycleOver(state, cfg);
    return {
        "status": state.status,
        "plain": plain,
        "kind": state.status === "ready" ? "ready" : state.status === "ended" ? "ended" : phase.kind,
        "endedKind": state.status === "ended" ? phase.kind : "",
        "remainingMs": remainingMs(state, cfg, now),
        "progress": progress(state, cfg, now),
        "round": round(state, cfg),
        "rounds": cfg.rounds,
        "focusMinutes": cfg.focus,
        "breakMinutes": cfg.brk,
        "next": upcoming ? { "kind": upcoming.kind, "ms": upcoming.ms, "round": upcoming.round } : null,
        "cycleOver": over,
        "done": state.done,
        "dots": dots(state, cfg),
        "dotFills": dotFills(state, cfg, now, 15000),
        "timeline": timeline(state, cfg, now),
        "cycleMs": derived(cfg).cycleMs,
        "longBreakAt": longBreakAt(state, cfg, now),
        "longAfter": cfg.longBreak > 0 ? cfg.rounds : 0,
        "phaseMs": phase ? phase.ms : 0
    };
}
