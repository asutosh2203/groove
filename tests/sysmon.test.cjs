const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const S = load('Sysmon.js');
const O = load('WidgetOptions.js');
const R = load('WidgetRegistry.js');
const reg = R.build(require('./manifests-source.cjs'));

const cfg = {
    windowMs: 120000, gapFactor: 3, gapMs: 15000, coolBy: 5, readyMs: 10000, rateFloor: 102400, cooldownMs: 600000,
    hot: { load: 90, cpuTemp: 90, gpuTemp: 85 }, sustainMs: { load: 60000, ram: 30000, temp: 30000 }
};
const GB = 1073741824;

// ---- subscriptions -------------------------------------------------------------------------------------------------
const preset = placements => [{ placements }];
const place = (pid, span, settings) => ({ pid, widget: 'system-monitor', span, settings: settings || {}, settingsVersion: 1 });

test('a span shows slot 1, slots 1-2 or slots 1-4, with the defaults cpu, gpu, ram, network', () => {
    const kinds = span => j(S.subscriptions(preset([place('a', span)]), reg))[0].kinds;
    assert.deepEqual(kinds('1x1'), ['cpu']);
    assert.deepEqual(kinds('2x1'), ['cpu', 'gpu']);
    assert.deepEqual(kinds('4x1'), ['cpu', 'gpu', 'ram', 'network']);
});

test('slot to sensor ids: a placement subscribes to its stats and their companions, once each', () => {
    const subs = j(S.subscriptions(preset([place('a', '2x1', { slot1: 'gpu', slot2: 'gpuTemp' }), place('b', '1x1', { slot1: 'gpu' })]), reg));
    assert.deepEqual(j(S.wanted(subs)), ['gpu/gpu0/name', 'gpu/gpu0/temperature', 'gpu/gpu0/usage']);
});

test('with no System Monitor placed nothing is wanted; other widgets are ignored', () => {
    assert.deepEqual(j(S.wanted([])), []);
    assert.deepEqual(j(S.subscriptions(preset([{ pid: 'x', widget: 'weather', span: '1x1', settings: {} }]), reg)), []);
});

test('an invalid stored slot falls back to the default', () => {
    assert.deepEqual(j(S.subscriptions(preset([place('a', '1x1', { slot1: 'bogus' })]), reg))[0].kinds, ['cpu']);
});

test('only hot kinds of alerting placements are armed; network and disk never alert', () => {
    const subs = j(S.subscriptions(preset([place('a', '4x1', { slot1: 'cpu', slot2: 'network', slot3: 'disk', slot4: 'gpuTemp', alerts: true }), place('b', '1x1', { slot1: 'ram' })]), reg));
    assert.deepEqual(j(S.alertKinds(subs)).sort(), ['cpu', 'gpuTemp']);
});

// ---- availability and readiness ------------------------------------------------------------------------------------
test('a kind is available when all its main sensors are listed; unknown listing disables nothing', () => {
    const ids = { 'memory/physical/used': true, 'gpu/gpu0/usage': true };
    assert.equal(S.kindAvailable('gpu', ids), true);
    assert.equal(S.kindAvailable('ram', ids), false);
    assert.equal(S.kindAvailable('ram', null), true);
    assert.equal(O.enabled('system-monitor', 'slot2', 'ram', { sensors: ids }), false);
    assert.equal(O.enabled('system-monitor', 'slot2', 'gpu', { sensors: ids }), true);
    assert.equal(O.enabled('system-monitor', 'alerts', 'ram', { sensors: ids }), true);
    assert.equal(O.enabled('weather', 'slot1', 'ram', { sensors: ids }), true);
});

test('a sensor not ready within 10 s is unresponsive; removed is an error at once', () => {
    assert.equal(S.health('ready', 99999, 10000), 'ready');
    assert.equal(S.health('loading', 9999, 10000), 'loading');
    assert.equal(S.health('loading', 10000, 10000), 'unresponsive');
    assert.equal(S.health('error', 20000, 10000), 'unresponsive');
    assert.equal(S.health('removed', 0, 10000), 'removed');
    assert.equal(S.statusName(2), 'ready');
});

test('kind state: missing, removed, unresponsive, loading, and ready only with a sample', () => {
    const ids = { 'gpu/gpu0/usage': true };
    assert.deepEqual(j(S.kindState('ram', ids, {}, {})), { state: 'error', reason: 'missing' });
    assert.deepEqual(j(S.kindState('gpu', ids, { 'gpu/gpu0/usage': 'removed' }, {})), { state: 'error', reason: 'removed' });
    assert.deepEqual(j(S.kindState('gpu', ids, { 'gpu/gpu0/usage': 'unresponsive' }, {})), { state: 'error', reason: 'unresponsive' });
    assert.equal(S.kindState('gpu', ids, { 'gpu/gpu0/usage': 'loading' }, {}).state, 'loading');
    assert.equal(S.kindState('gpu', ids, { 'gpu/gpu0/usage': 'ready' }, {}).state, 'loading');
    assert.equal(S.kindState('gpu', ids, { 'gpu/gpu0/usage': 'ready' }, { 'gpu/gpu0/usage': 0 }).state, 'ready');
    assert.equal(S.kindState('ram', null, { 'memory/physical/used': 'ready', 'memory/physical/total': 'ready' }, { 'memory/physical/used': 1 }).state, 'loading');
});

// ---- history -------------------------------------------------------------------------------------------------------
test('the ring keeps samples inside the window and drops older ones', () => {
    let s = [];
    for (let t = 0; t <= 300000; t += 5000) s = j(S.push(s, t, t / 1000, 5000, 120000));
    assert.equal(s[0].t, 180000);
    assert.equal(s.length, 25);
    assert.equal(s[s.length - 1].t, 300000);
});

test('changing the window changes what is kept', () => {
    let s = [];
    for (let t = 0; t <= 100000; t += 1000) s = j(S.push(s, t, 1, 1000, 30000));
    assert.equal(s.length, 31);
});

test('a gap wider than 3 ticks breaks the line; the slower cadence of the pair decides', () => {
    const pts = [{ t: 0, v: 1, tick: 1000 }, { t: 1000, v: 1, tick: 1000 }, { t: 5000, v: 1, tick: 1000 }, { t: 6000, v: 1, tick: 1000 }];
    assert.deepEqual(j(S.split(pts, 3)).map(s => s.length), [2, 2]);
    // a hidden stretch at 5 s followed by a visible one at 1 s is not a gap
    const mixed = [{ t: 0, v: 1, tick: 5000 }, { t: 5000, v: 1, tick: 5000 }, { t: 10000, v: 1, tick: 5000 }, { t: 11000, v: 1, tick: 1000 }, { t: 12000, v: 1, tick: 1000 }];
    assert.equal(j(S.split(mixed, 3)).length, 1);
    // a lock of a minute breaks even a hidden line
    assert.equal(j(S.split([{ t: 0, v: 1, tick: 5000 }, { t: 60000, v: 1, tick: 5000 }], 3)).length, 2);
    assert.deepEqual(j(S.split([], 3)), []);
});

// ---- values and formatting -----------------------------------------------------------------------------------------
test('formatting: whole % and whole degrees', () => {
    assert.equal(S.fmtPct(36.6), '37%');
    assert.equal(S.fmtTemp(62.4), '62°C');
    assert.equal(S.fmtTemp(49.625), '50°C');
});

test('RAM is binary GB with one decimal and the binary total', () => {
    const d = S.display('ram', { 'memory/physical/used': 8184868864, 'memory/physical/total': 15655022592 });
    assert.deepEqual(j(d), { hero: '7.6', suffix: '/ 14.6 GB' });
    assert.equal(S.fmtGB(9.8 * GB), '9.8');
});

test('rates are bytes per second with 1024 steps and the busier direction', () => {
    assert.deepEqual(j(S.fmtRate(0)), { num: '0', unit: 'B/s' });
    assert.deepEqual(j(S.fmtRate(900)), { num: '900', unit: 'B/s' });
    assert.deepEqual(j(S.fmtRate(12.4 * 1048576)), { num: '12.4', unit: 'MB/s' });
    assert.deepEqual(j(S.fmtRate(250 * 1024)), { num: '250', unit: 'KB/s' });
    assert.deepEqual(j(S.display('network', { 'network/all/download': 3 * 1048576, 'network/all/upload': 100 })), { hero: '3.0', suffix: '↓ MB/s' });
    assert.deepEqual(j(S.display('network', { 'network/all/download': 100, 'network/all/upload': 2048 })), { hero: '2.0', suffix: '↑ KB/s' });
    assert.equal(S.display('disk', { 'disk/all/read': 5, 'disk/all/write': 1 }).suffix, '↓ B/s');
});

test('loads and temperatures show as hero text; nothing before a sample', () => {
    assert.deepEqual(j(S.display('cpu', { 'cpu/all/usage': 4.36 })), { hero: '4%', suffix: '' });
    assert.deepEqual(j(S.display('gpuTemp', { 'gpu/gpu0/temperature': 43 })), { hero: '43°C', suffix: '' });
    assert.equal(S.display('cpu', {}), null);
    assert.equal(S.display('cpu', { 'cpu/all/usage': NaN }), null);
});

test('the companion line is chosen by kind', () => {
    const l = { 'cpu/all/maximumTemperature': 51, 'cpu/all/usage': 12, 'gpu/gpu0/usage': 74, 'gpu/gpu0/temperature': 43, 'memory/physical/used': GB, 'memory/physical/total': 8 * GB, 'memory/swap/used': 0.4 * GB, 'network/all/download': 2048, 'network/all/upload': 512 };
    const texts = { 'gpu/gpu0/name': 'NVIDIA GeForce RTX 4060' };
    assert.deepEqual(j(S.companion('cpu', l, texts)), { key: 'temp', value: '51°C' });
    assert.deepEqual(j(S.companion('gpu', l, texts)), { key: 'gpu', name: 'NVIDIA GeForce RTX 4060', value: '43°C' });
    assert.deepEqual(j(S.companion('ram', l, texts)), { key: 'swap', value: '0.4 GB' });
    assert.deepEqual(j(S.companion('cpuTemp', l, texts)), { key: 'load', value: '12%' });
    assert.deepEqual(j(S.companion('gpuTemp', l, texts)), { key: 'load', value: '74%' });
    assert.deepEqual(j(S.companion('network', l, texts)), { key: 'other', value: '↑ 512 B/s' });
    assert.equal(S.companion('cpu', { 'cpu/all/usage': 5 }, texts), null);
});

test('RAM is hot as a share of the binary total; alerts quote % or degrees', () => {
    const l = { 'memory/physical/used': 13 * GB, 'memory/physical/total': 14.6 * GB };
    assert.equal(Math.round(S.reading('ram', l).pct), 89);
    assert.equal(S.alertValue('ram', { 'memory/physical/used': 14 * GB, 'memory/physical/total': 14.6 * GB }), '96%');
    assert.equal(S.alertValue('gpuTemp', { 'gpu/gpu0/temperature': 87 }), '87°C');
    assert.equal(S.alertValue('network', { 'network/all/download': 1, 'network/all/upload': 1 }), '');
});

// ---- hot level -----------------------------------------------------------------------------------------------------
test('hysteresis: hot at the threshold, still hot at the edge, cool only below threshold - 5', () => {
    let hot = false;
    const step = v => (hot = S.hotNext(hot, v, 90, 5));
    assert.equal(step(89.9), false);
    assert.equal(step(90), true);
    assert.equal(step(86), true);
    assert.equal(step(85), true);
    assert.equal(step(84.9), false);
    assert.equal(step(88), false);
    assert.equal(step(90), true);
    assert.equal(S.hotNext(true, 100, null, 5), false);
});

test('thresholds per kind; none for network and disk', () => {
    assert.equal(S.thresholdFor('cpu', cfg.hot), 90);
    assert.equal(S.thresholdFor('ram', cfg.hot), 90);
    assert.equal(S.thresholdFor('cpuTemp', cfg.hot), 90);
    assert.equal(S.thresholdFor('gpuTemp', cfg.hot), 85);
    assert.equal(S.thresholdFor('network', cfg.hot), null);
    assert.equal(S.thresholdFor('disk', cfg.hot), null);
    assert.equal(S.sustainFor('gpu', cfg.sustainMs), 60000);
    assert.equal(S.sustainFor('ram', cfg.sustainMs), 30000);
    assert.equal(S.sustainFor('gpuTemp', cfg.sustainMs), 30000);
    assert.equal(S.sustainFor('disk', cfg.sustainMs), null);
});

// ---- alerts --------------------------------------------------------------------------------------------------------
function run(samples, kind, armed) {
    const sustain = S.sustainFor(kind, cfg.sustainMs);
    let st = S.initialAlert();
    const fires = [];
    for (const [t, v] of samples) {
        const r = j(S.alertStep(st, v, S.thresholdFor(kind, cfg.hot), armed !== false, t, cfg, sustain));
        st = r.state;
        if (r.fire) fires.push([t, r.fire.value, r.fire.seconds]);
    }
    return { fires, st };
}
const every = (from, to, step, v) => { const out = []; for (let t = from; t <= to; t += step) out.push([t, v]); return out; };

test('an alert needs the stat hot continuously for the sustain time', () => {
    const { fires } = run(every(5000, 120000, 5000, 95), 'gpu');
    assert.deepEqual(fires, [[65000, 95, 60]]);
});

test('the sustain clock resets when the value drops below the hysteresis exit', () => {
    const samples = to => every(5000, 50000, 5000, 95).concat(every(55000, 60000, 5000, 80), every(65000, to, 5000, 95));
    // without the reset it would have fired at 65 s; with it, a full minute counts from 65 s
    assert.deepEqual(run(samples(120000), 'gpu').fires, []);
    assert.deepEqual(run(samples(130000), 'gpu').fires.map(f => f[0]), [125000]);
});

test('hovering at the edge keeps the clock; a dip to 86 does not reset it', () => {
    const samples = every(5000, 30000, 5000, 95).concat(every(35000, 40000, 5000, 86), every(45000, 70000, 5000, 95));
    assert.deepEqual(run(samples, 'gpu').fires.map(f => f[0]), [65000]);
});

test('a temperature alerts after 30 s and RAM after 30 s', () => {
    assert.deepEqual(run(every(1000, 40000, 1000, 87), 'gpuTemp').fires.map(f => f[0]), [31000]);
    assert.deepEqual(run(every(1000, 40000, 1000, 95), 'ram').fires.map(f => f[0]), [31000]);
});

test('one alert per 10 minutes per sensor, then again if it is still hot', () => {
    const fires = run(every(1000, 1500000, 1000, 95), 'gpuTemp').fires.map(f => f[0]);
    assert.deepEqual(fires, [31000, 631000, 1231000]);
});

test('cooldown is per sensor: the same sample stream evaluated once however many placements show it', () => {
    // The hub steps each kind once per sample, so two placements cannot double-notify; two kinds are independent.
    const a = run(every(1000, 40000, 1000, 95), 'gpuTemp').fires.length;
    const b = run(every(1000, 40000, 1000, 95), 'cpuTemp').fires.length;
    assert.equal(a + b, 2);
});

test('an unarmed sensor never fires but still tracks hot; arming later fires at once if it has been hot long enough', () => {
    const sustain = 30000;
    let st = S.initialAlert();
    for (let t = 1000; t <= 40000; t += 1000) st = j(S.alertStep(st, 95, 85, false, t, cfg, sustain)).state;
    assert.equal(st.hot, true);
    assert.equal(st.lastFire, 0);
    assert.notEqual(j(S.alertStep(st, 95, 85, true, 41000, cfg, sustain)).fire, null);
});

test('a gap in sampling (sleep, lock) restarts the clock', () => {
    const samples = every(1000, 20000, 1000, 95).concat(every(3600000, 3640000, 1000, 95));
    assert.deepEqual(run(samples, 'gpuTemp').fires.map(f => f[0]), [3630000]);
});

test('a rate never alerts', () => {
    assert.deepEqual(run(every(1000, 100000, 1000, 1e9), 'network').fires, []);
});

// ---- the sparkline -------------------------------------------------------------------------------------------------
const ring = (id, from, to, step, v, tick) => { const out = {}; out[id] = []; for (let t = from; t <= to; t += step) out[id].push({ t, v: typeof v === 'function' ? v(t) : v, tick }); return out; };

test('a percentage uses a fixed 0-100 scale, so the threshold sits at its real height', () => {
    const rings = ring('cpu/all/usage', 0, 120000, 1000, 50, 1000);
    const p = j(S.plot('cpu', rings, {}, 120000, cfg, 120, 40));
    assert.equal(p.segments.length, 1);
    assert.equal(p.segments[0][0].x, 0);
    assert.equal(p.segments[0][120].x, 120);
    assert.equal(p.segments[0][0].y, 20);
});

test('x is the age in the window; samples older than the window are not drawn; the window token sets the span', () => {
    const rings = ring('cpu/all/usage', 0, 120000, 1000, 50, 1000);
    const p = j(S.plot('cpu', rings, {}, 120000, { ...cfg, windowMs: 60000 }, 60, 10));
    assert.equal(p.segments[0][0].x, 0);
    assert.equal(p.segments[0].length, 61);
});

test('a gap splits the drawn line into segments', () => {
    const r = ring('cpu/all/usage', 0, 10000, 1000, 10, 1000);
    r['cpu/all/usage'] = r['cpu/all/usage'].concat([{ t: 60000, v: 10, tick: 1000 }, { t: 61000, v: 10, tick: 1000 }]);
    assert.equal(j(S.plot('cpu', r, {}, 61000, cfg, 120, 40)).segments.length, 2);
});

test('RAM plots its share of the total; a rate auto-scales to the window peak with a floor', () => {
    const ram = ring('memory/physical/used', 0, 10000, 1000, 5 * GB, 1000);
    const p = j(S.plot('ram', ram, { 'memory/physical/total': 10 * GB }, 10000, cfg, 100, 40));
    assert.equal(p.segments[0][0].y, 20);
    const idle = Object.assign(ring('network/all/download', 0, 5000, 1000, 1000, 1000), ring('network/all/upload', 0, 5000, 1000, 10, 1000));
    const q = j(S.plot('network', idle, {}, 5000, cfg, 100, 40));
    assert.ok(q.segments[0][0].y > 39, 'idle stays near the bottom (floor)');
    const busy = Object.assign(ring('network/all/download', 0, 5000, 1000, (t) => t === 3000 ? 10485760 : 1000, 1000), ring('network/all/upload', 0, 5000, 1000, 0, 1000));
    const b = j(S.plot('network', busy, {}, 5000, cfg, 100, 40));
    assert.equal(Math.min(...b.segments[0].map(s => s.y)), 0);
});

test('the rate floor and scale', () => {
    assert.equal(S.rateScale(10, 102400), 102400);
    assert.equal(S.rateScale(1e6, 102400), 1e6);
});

test('nothing to draw before a sample', () => {
    assert.deepEqual(j(S.plot('cpu', {}, {}, 1000, cfg, 100, 40)), { segments: [], line: '', fill: '' });
});

// ---- smoothing -----------------------------------------------------------------------------------------------------
// Parses "M x y C a b c d x y ..." subpaths (and the fill's closing L L Z) into cubic segments.
function beziers(path) {
    const out = [];
    for (const sub of path.split(/(?=M)/).filter(Boolean)) {
        const nums = sub.replace(/[MCLZ]/g, ' ').trim().split(/\s+/).map(Number);
        let [x, y] = nums;
        const cmds = sub.match(/[MCLZ]/g);
        let k = 2;
        for (const c of cmds.slice(1)) {
            if (c === 'C') { out.push({ p0: [x, y], p1: [nums[k], nums[k + 1]], p2: [nums[k + 2], nums[k + 3]], p3: [nums[k + 4], nums[k + 5]] }); x = nums[k + 4]; y = nums[k + 5]; k += 6; }
            else if (c === 'L') { x = nums[k]; y = nums[k + 1]; k += 2; }
        }
    }
    return out;
}
const bez = (b, t, i) => (1 - t) ** 3 * b.p0[i] + 3 * (1 - t) ** 2 * t * b.p1[i] + 3 * (1 - t) * t * t * b.p2[i] + t ** 3 * b.p3[i];
function rng(seed) { let a = seed; return () => { a = (a * 1664525 + 1013904223) % 4294967296; return a / 4294967296; }; }

test('monotone: every curve segment stays within its two samples, for random series (no invented peaks)', () => {
    const r = rng(7);
    for (let n = 0; n < 200; ++n) {
        const len = 2 + Math.floor(r() * 30);
        const pts = [];
        let x = 0;
        for (let i = 0; i < len; ++i) { x += 1 + r() * 9; pts.push({ x, y: r() * 40 }); }
        const path = S.monotonePath(pts);
        const segs = beziers(path);
        assert.equal(segs.length, len - 1);
        segs.forEach((b, i) => {
            const lo = Math.min(pts[i].y, pts[i + 1].y) - 0.01, hi = Math.max(pts[i].y, pts[i + 1].y) + 0.01; // the path is rounded to 0.01 px
            for (let t = 0; t <= 1; t += 0.05) {
                const yy = bez(b, t, 1), xx = bez(b, t, 0);
                assert.ok(yy >= lo && yy <= hi, `y ${yy} outside [${lo}, ${hi}]`);
                assert.ok(xx >= pts[i].x - 0.01 && xx <= pts[i + 1].x + 0.01, 'x stays between the samples');
            }
        });
    }
});

test('monotone: x never goes backwards along the curve; the curve passes through every sample', () => {
    const pts = [{ x: 0, y: 5 }, { x: 10, y: 30 }, { x: 11, y: 2 }, { x: 40, y: 2 }, { x: 50, y: 39 }];
    const segs = beziers(S.monotonePath(pts));
    segs.forEach((b, i) => {
        assert.deepEqual(b.p0, [pts[i].x, pts[i].y]);
        assert.deepEqual(b.p3, [pts[i + 1].x, pts[i + 1].y]);
        let last = -Infinity;
        for (let t = 0; t <= 1; t += 0.02) { const xx = bez(b, t, 0); assert.ok(xx >= last - 1e-9); last = xx; }
    });
});

test('flat runs stay flat, and a plateau between two rises has flat tangents on it', () => {
    const flat = beziers(S.monotonePath([{ x: 0, y: 12 }, { x: 5, y: 12 }, { x: 11, y: 12 }, { x: 20, y: 12 }]));
    flat.forEach(b => { for (let t = 0; t <= 1; t += 0.1) assert.ok(Math.abs(bez(b, t, 1) - 12) < 1e-9); });
    const peak = beziers(S.monotonePath([{ x: 0, y: 30 }, { x: 10, y: 10 }, { x: 20, y: 30 }]));
    assert.ok(peak.every(b => { for (let t = 0; t <= 1; t += 0.05) if (bez(b, t, 1) < 10 - 1e-9 || bez(b, t, 1) > 30 + 1e-9) return false; return true; }));
});

test('a run of fewer than two samples draws nothing (documented: a lone sample is not worth a dot)', () => {
    assert.equal(S.monotonePath([]), null);
    assert.equal(S.monotonePath([{ x: 3, y: 3 }]), null);
    assert.deepEqual(j(S.curves([[{ x: 3, y: 3 }]], 40)), { line: '', fill: '' });
});

test('gaps: each run is its own subpath, and each fill closes to the baseline on its own', () => {
    const runs = [[{ x: 0, y: 10 }, { x: 10, y: 20 }], [{ x: 50, y: 5 }, { x: 60, y: 5 }, { x: 70, y: 30 }]];
    const c = j(S.curves(runs, 40));
    assert.equal(c.line.split('M').length - 1, 2);
    assert.equal(c.fill.split('M').length - 1, 2);
    assert.equal(c.fill.split('Z').length - 1, 2);
    const fills = c.fill.split(/(?=M)/).map(f => f.trim());
    assert.ok(fills[0].endsWith('L10 40L0 40Z'));
    assert.ok(fills[1].endsWith('L70 40L50 40Z'));
    assert.ok(!c.line.includes('Z') && !c.line.includes('L'));
});

test('plot gives the paths for a real ring and splits at a gap', () => {
    const r = ring('cpu/all/usage', 0, 10000, 1000, 10, 1000);
    r['cpu/all/usage'] = r['cpu/all/usage'].concat([{ t: 60000, v: 90, tick: 1000 }, { t: 61000, v: 90, tick: 1000 }]);
    const p = j(S.plot('cpu', r, {}, 61000, cfg, 120, 40));
    assert.equal(p.line.split('M').length - 1, 2);
    assert.ok(p.fill.endsWith('Z'));
    const y = /M[\d.]+ ([\d.]+)/.exec(p.line)[1];
    assert.equal(Number(y), 36);
});
