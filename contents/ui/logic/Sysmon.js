.pragma library
.import "WidgetRegistry.js" as Registry

// The System Monitor's decisions (D-65): which sensors a slot reads, the in-memory history and its gaps, the hot level with
// hysteresis, the alert state machine, formatting and the sparkline geometry. Pure; the hub (SysmonHub.qml) executes.
// `cfg` carries the Tokens: windowMs, gapFactor, coolBy, hot { load, cpuTemp, gpuTemp }, sustainMs { load, ram, temp },
// cooldownMs, readyMs, rateFloor. hot: { load, ramGB, cpuTemp, gpuTemp }.

// main: what the hero needs (all must exist). extra: companion-line sensors (optional). hot: threshold key; sustain: alert key.
const KINDS = {
    "cpu": { "main": ["cpu/all/usage"], "extra": ["cpu/all/maximumTemperature"], "hot": "load", "sustain": "load" },
    "gpu": { "main": ["gpu/gpu0/usage"], "extra": ["gpu/gpu0/temperature", "gpu/gpu0/name"], "hot": "load", "sustain": "load" },
    "ram": { "main": ["memory/physical/used", "memory/physical/total"], "extra": ["memory/swap/used"], "hot": "ram", "sustain": "ram" },
    "cpuTemp": { "main": ["cpu/all/maximumTemperature"], "extra": ["cpu/all/usage"], "hot": "cpuTemp", "sustain": "temp" },
    "gpuTemp": { "main": ["gpu/gpu0/temperature"], "extra": ["gpu/gpu0/usage"], "hot": "gpuTemp", "sustain": "temp" },
    "network": { "main": ["network/all/download", "network/all/upload"], "extra": [], "hot": null, "sustain": null },
    "disk": { "main": ["disk/all/read", "disk/all/write"], "extra": [], "hot": null, "sustain": null }
};
const STATUS = ["unknown", "loading", "ready", "error", "removed"];
const SLOT_KEYS = ["slot1", "slot2", "slot3", "slot4"];
const GB = 1073741824;

function kinds() {
    return Object.keys(KINDS);
}

function mainIds(kind) {
    return KINDS[kind] ? KINDS[kind].main : [];
}

function idsOf(kind) {
    return KINDS[kind] ? KINDS[kind].main.concat(KINDS[kind].extra) : [];
}

// ---- Subscriptions -------------------------------------------------------------------------------------------------

// The kinds a span shows: slot1 on a 1x1, slot1-2 on a 2x1, slot1-4 on a 4x1.
function slotKinds(settings, span) {
    const n = span === "4x1" ? 4 : span === "2x1" ? 2 : 1;
    return SLOT_KEYS.slice(0, n).map(k => String(settings[k])).filter(k => KINDS[k] !== undefined);
}

// presets: [{ placements: [{ pid, widget, span, settings, settingsVersion }] }] -> [{ pid, kinds, alerts }].
function subscriptions(presets, registry) {
    const manifest = registry.byId["system-monitor"];
    if (!manifest)
        return [];
    return presets.reduce((all, p) => all.concat(p.placements), []).filter(p => p.widget === "system-monitor").map(p => {
        const s = Registry.resolveSettings(manifest, p.settings, p.settingsVersion);
        return { "pid": String(p.pid), "kinds": slotKinds(s, p.span), "alerts": s.alerts === true };
    });
}

function wantedKinds(subs) {
    return Object.keys(subs.reduce((set, s) => s.kinds.reduce((m, k) => (m[k] = true, m), set), {}));
}

// Every sensor id some placement shows, once.
function wanted(subs) {
    const set = {};
    for (const k of wantedKinds(subs))
        for (const id of idsOf(k))
            set[id] = true;
    return Object.keys(set).sort();
}

function alertKinds(subs) {
    return wantedKinds(subs.filter(s => s.alerts)).filter(k => KINDS[k].hot !== null);
}

// ---- Availability and readiness ------------------------------------------------------------------------------------

// ids: the sensor ids the daemon lists, or null while unknown (nothing is disabled then).
function kindAvailable(kind, ids) {
    return ids === null || ids === undefined || mainIds(kind).every(id => ids[id] === true);
}

function statusName(n) {
    return STATUS[n] || "unknown";
}

// One sensor: ready, loading, unresponsive (not ready within readyMs) or removed.
function health(status, ageMs, readyMs) {
    if (status === "ready")
        return "ready";
    if (status === "removed")
        return "removed";
    return ageMs >= readyMs ? "unresponsive" : "loading";
}

// -> { state: "loading" | "ready" | "error", reason: "" | "missing" | "unresponsive" | "removed" }. Never ready before every
// main sensor has a sample.
function kindState(kind, ids, healths, latest) {
    if (!kindAvailable(kind, ids))
        return { "state": "error", "reason": "missing" };
    const main = mainIds(kind);
    for (const reason of ["removed", "unresponsive"])
        if (main.some(id => healths[id] === reason))
            return { "state": "error", "reason": reason };
    return { "state": main.every(id => healths[id] === "ready" && typeof latest[id] === "number") ? "ready" : "loading", "reason": "" };
}

// ---- History -------------------------------------------------------------------------------------------------------

// A new series with the sample added, older than the window dropped. `tick` is the cadence in force, kept so a later change
// of cadence does not read as a gap.
function push(series, t, v, tick, windowMs) {
    const from = t - windowMs;
    return (series || []).filter(p => p.t >= from).concat([{ "t": t, "v": v, "tick": tick }]);
}

// Polylines split wherever two samples are further apart than gapFactor times the slower cadence of the pair.
function split(points, gapFactor) {
    const out = [];
    let cur = [];
    points.forEach((p, i) => {
        if (i > 0 && p.t - points[i - 1].t > gapFactor * Math.max(p.tick, points[i - 1].tick)) {
            out.push(cur);
            cur = [];
        }
        cur.push(p);
    });
    if (cur.length > 0)
        out.push(cur);
    return out;
}

// ---- Values --------------------------------------------------------------------------------------------------------

function num(v) {
    return typeof v === "number" && isFinite(v) ? v : null;
}

// What a kind currently reads: pct (0-100, the hot and scale axis, or null for a rate), value (the number shown) and, for a
// rate, both directions. Null while a main sensor has no sample.
function reading(kind, latest) {
    const ids = mainIds(kind);
    if (!KINDS[kind] || ids.some(id => num(latest[id]) === null))
        return null;
    if (kind === "ram") {
        const total = latest[ids[1]];
        return { "value": latest[ids[0]], "total": total, "pct": total > 0 ? Math.min(100, latest[ids[0]] / total * 100) : 0 };
    }
    if (KINDS[kind].hot === null)
        return { "value": Math.max(latest[ids[0]], latest[ids[1]]), "down": latest[ids[0]], "up": latest[ids[1]], "pct": null };
    return { "value": latest[ids[0]], "pct": latest[ids[0]] };
}

function sustainFor(kind, sustainMs) {
    return KINDS[kind] && KINDS[kind].sustain !== null ? sustainMs[KINDS[kind].sustain] : null;
}

// The hot level on the 0-100 axis. RAM's is an absolute amount (hot.ramGB), so it is that amount's share of this machine's total;
// null until the total is known.
function thresholdFor(kind, hot, latest) {
    if (!KINDS[kind] || KINDS[kind].hot === null)
        return null;
    if (kind !== "ram")
        return hot[KINDS[kind].hot];
    const total = latest ? num(latest[mainIds(kind)[1]]) : null;
    return total > 0 ? Math.min(100, hot.ramGB * GB / total * 100) : null;
}

// ---- Formatting ----------------------------------------------------------------------------------------------------

function fmtPct(v) {
    return Math.round(v) + "%";
}

function fmtTemp(v) {
    return Math.round(v) + "°C";
}

// Binary, labelled GB like KDE's formatter.
function fmtGB(bytes) {
    return (bytes / GB).toFixed(1);
}

function fmtRate(bps) {
    const units = ["B/s", "KB/s", "MB/s", "GB/s"];
    let i = 0;
    let v = Math.max(0, bps);
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return { "num": i === 0 ? String(Math.round(v)) : v < 100 ? v.toFixed(1) : String(Math.round(v)), "unit": units[i] };
}

// The face of a kind: hero text, the small suffix after it, and its arrow for a rate.
function display(kind, latest) {
    const r = reading(kind, latest);
    if (r === null)
        return null;
    if (kind === "ram")
        return { "hero": fmtGB(r.value), "suffix": "/ " + fmtGB(r.total) + " GB" };
    if (KINDS[kind].hot === null) {
        const f = fmtRate(r.value);
        return { "hero": f.num, "suffix": (r.down >= r.up ? "↓ " : "↑ ") + f.unit };
    }
    return { "hero": KINDS[kind].hot === "load" ? fmtPct(r.value) : fmtTemp(r.value), "suffix": "" };
}

// The value an alert quotes: a percentage for loads, GB for memory, degrees for temperatures.
function alertValue(kind, latest) {
    const r = reading(kind, latest);
    if (r === null || !KINDS[kind] || KINDS[kind].hot === null)
        return "";
    return kind === "ram" ? fmtGB(r.value) + " GB" : KINDS[kind].hot === "load" ? fmtPct(r.pct) : fmtTemp(r.value);
}

// The extra line a tall box adds, chosen here: { key, value } or { key: "gpu", name, value }; null when its sensor is missing.
function companion(kind, latest, texts) {
    const r = reading(kind, latest);
    if (r === null)
        return null;
    const at = id => num(latest[id]);
    if (kind === "cpu")
        return at("cpu/all/maximumTemperature") === null ? null : { "key": "temp", "value": fmtTemp(at("cpu/all/maximumTemperature")) };
    if (kind === "gpu")
        return at("gpu/gpu0/temperature") === null ? null : { "key": "gpu", "name": String(texts["gpu/gpu0/name"] || ""), "value": fmtTemp(at("gpu/gpu0/temperature")) };
    if (kind === "ram")
        return at("memory/swap/used") === null ? null : { "key": "swap", "value": fmtGB(at("memory/swap/used")) + " GB" };
    if (kind === "cpuTemp")
        return at("cpu/all/usage") === null ? null : { "key": "load", "value": fmtPct(at("cpu/all/usage")) };
    if (kind === "gpuTemp")
        return at("gpu/gpu0/usage") === null ? null : { "key": "load", "value": fmtPct(at("gpu/gpu0/usage")) };
    const down = r.down >= r.up;
    const f = fmtRate(down ? r.up : r.down);
    return { "key": "other", "value": (down ? "↑ " : "↓ ") + f.num + " " + f.unit };
}

// ---- Hot level and alerts ------------------------------------------------------------------------------------------

// Hot from `threshold`, cool again only below threshold - coolBy. `prev` is the explicit state.
function hotNext(prev, value, threshold, coolBy) {
    if (threshold === null || threshold === undefined)
        return false;
    return prev ? value >= threshold - coolBy : value >= threshold;
}

function initialAlert() {
    return { "hot": false, "since": 0, "lastFire": 0, "lastT": 0 };
}

// One sample of one sensor. `armed`: some placement has alerts on. A hot stretch counts from the first hot sample, restarts
// after a gap in sampling (sleep, lock) and ends below the hysteresis exit. One alert per cooldown, per sensor, however many
// placements show it. -> { state, fire: { value, seconds } | null }.
function alertStep(state, value, threshold, armed, now, cfg, sustainMs) {
    const gap = state.lastT > 0 && now - state.lastT > cfg.gapMs;
    const hot = hotNext(gap ? false : state.hot, value, threshold, cfg.coolBy);
    const since = !hot ? 0 : state.hot && !gap ? state.since : now;
    const due = armed && hot && now - since >= sustainMs && (state.lastFire === 0 || now - state.lastFire >= cfg.cooldownMs);
    return {
        "state": { "hot": hot, "since": since, "lastFire": due ? now : state.lastFire, "lastT": now },
        "fire": due ? { "value": value, "seconds": Math.round((now - since) / 1000) } : null
    };
}

// ---- The sparkline -------------------------------------------------------------------------------------------------

// The y axis maximum of a rate: the window's peak, never below the floor, so an idle line stays flat and low.
function rateScale(peak, floor) {
    return Math.max(peak, floor);
}

// ---- Smoothing -----------------------------------------------------------------------------------------------------

function round2(v) {
    return Math.round(v * 100) / 100;
}

// Fritsch-Carlson tangents for points with ascending x: a curve through them never leaves the range of the two samples it
// joins, so it invents no peak and a flat run stays flat.
function tangents(pts) {
    const n = pts.length;
    const d = [];
    for (let i = 0; i < n - 1; ++i) {
        const dx = pts[i + 1].x - pts[i].x;
        d.push(dx > 0 ? (pts[i + 1].y - pts[i].y) / dx : 0);
    }
    const m = pts.map((p, i) => i === 0 ? d[0] : i === n - 1 ? d[n - 2] : d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2);
    for (let i = 0; i < n - 1; ++i) {
        if (d[i] === 0) {
            m[i] = 0;
            m[i + 1] = 0;
            continue;
        }
        const a = m[i] / d[i];
        const b = m[i + 1] / d[i];
        const sum = a * a + b * b;
        if (sum > 9) {
            const t = 3 / Math.sqrt(sum);
            m[i] = t * a * d[i];
            m[i + 1] = t * b * d[i];
        }
    }
    return m;
}

// One unbroken run as an SVG path: M, then a cubic per segment. Null for fewer than two samples (a lone sample draws nothing:
// the next one a second later joins it, and an isolated one after a gap is not worth a dot).
function monotonePath(pts) {
    if (pts.length < 2)
        return null;
    const m = tangents(pts);
    let path = "M" + round2(pts[0].x) + " " + round2(pts[0].y);
    for (let i = 0; i < pts.length - 1; ++i) {
        const dx = (pts[i + 1].x - pts[i].x) / 3;
        path += "C" + round2(pts[i].x + dx) + " " + round2(pts[i].y + m[i] * dx) + " " + round2(pts[i + 1].x - dx) + " " + round2(pts[i + 1].y - m[i + 1] * dx) + " " + round2(pts[i + 1].x) + " " + round2(pts[i + 1].y);
    }
    return path;
}

// The runs as { line, fill }: each run its own subpath, and each fill closed to the baseline (y = h) on its own.
function curves(runs, h) {
    const lines = [];
    const fills = [];
    for (const run of runs) {
        const path = monotonePath(run);
        if (path === null)
            continue;
        lines.push(path);
        fills.push(path + "L" + round2(run[run.length - 1].x) + " " + h + "L" + round2(run[0].x) + " " + h + "Z");
    }
    return { "line": lines.join(" "), "fill": fills.join(" ") };
}

// ---- The sparkline -------------------------------------------------------------------------------------------------

// The graph of a kind: { segments: [[{x, y}]], line, fill }. x is the sample's age in the window, y a fixed 0-100 scale for
// percentages and temperatures and the window's peak for a rate; line and fill are SVG paths for those runs (curves).
function plot(kind, rings, latest, now, cfg, w, h) {
    const empty = { "segments": [], "line": "", "fill": "" };
    const ids = mainIds(kind);
    if (!KINDS[kind] || !rings[ids[0]])
        return empty;
    const rate = KINDS[kind].hot === null;
    let pts;
    if (rate) {
        const up = {};
        (rings[ids[1]] || []).forEach(p => up[p.t] = p.v);
        pts = rings[ids[0]].filter(p => up[p.t] !== undefined).map(p => ({ "t": p.t, "tick": p.tick, "v": Math.max(p.v, up[p.t]) }));
    } else if (kind === "ram") {
        const total = num(latest[ids[1]]);
        pts = total > 0 ? rings[ids[0]].map(p => ({ "t": p.t, "tick": p.tick, "v": Math.min(100, p.v / total * 100) })) : [];
    } else
        pts = rings[ids[0]];
    const max = rate ? rateScale(pts.reduce((m, p) => Math.max(m, p.v), 0), cfg.rateFloor) : 100;
    const from = now - cfg.windowMs;
    const y = v => h - Math.min(1, Math.max(0, v / max)) * h;
    const segments = split(pts.filter(p => p.t >= from), cfg.gapFactor).map(seg => seg.map(p => ({ "x": (p.t - from) / cfg.windowMs * w, "y": y(p.v) })));
    return Object.assign({ "segments": segments }, curves(segments, h));
}

// ---- Settings form -------------------------------------------------------------------------------------------------

// Whether the sensors behind an enum option exist (WidgetOptions.js asks); an unknown option stays enabled.
function optionAvailable(option, ids) {
    return KINDS[option] === undefined || kindAvailable(option, ids);
}
