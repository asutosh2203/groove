const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against decidePanel / handlePanelReply / panelCommand / screenForPoint as they were in main.qml. The
// scenarios are the contract: a floating Pill panel attaches for Notch and is restored for Pill, only the panel the
// originals came from is ever touched, and an uncertain panel is left alone.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const base = vm.createContext({ isFinite, Number, Math, String });
vm.runInContext(read('Utils.js'), base);
const ctx = vm.createContext({ Utils: { finiteNumber: base.finiteNumber, shellQuote: base.shellQuote }, Math, Number, JSON, String });
vm.runInContext(read('PanelPlan.js'), ctx);
const P = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));
const NOTCH = 40;
const none = { panelId: 0, floating: -1, thickness: 0 };

test('the command finds the panel by id, checks it holds this applet, and only changes what it is told', () => {
    const read_ = P.command(113, 200, null, 0);
    assert.match(read_, /panelById\(113\)/);
    assert.match(read_, /widgetIds\.indexOf\(200\) >= 0/);
    assert.doesNotMatch(read_, /p\.floating = /);
    assert.doesNotMatch(read_, /p\.height = /);
    const write = P.command(113, 200, false, 40);
    assert.match(write, /p\.floating = false;/);
    assert.match(write, /p\.height = 40;/);
    assert.match(write, /^qdbus6 org\.kde\.plasmashell \/PlasmaShell org\.kde\.PlasmaShell\.evaluateScript '/);
});

test('ids are floored to digits so nothing else can reach the script', () => {
    const c = P.command('7; evil()', 2.9, null, 0);
    assert.match(c, /panelById\(NaN\)/); // a hostile id becomes NaN, which matches no panel
    assert.doesNotMatch(c, /evil/);
    assert.match(P.command(7.9, 2.9, null, 0), /panelById\(7\).*indexOf\(2\)/);
});

test('replies are recognised by their prefix and parsed, bad ones read as not ok', () => {
    assert.equal(P.isReply('DI_PANEL {"ok":true}\n'), true);
    assert.equal(P.isReply('error: no such service'), false);
    assert.deepEqual(j(P.parseReply('DI_PANEL {"ok":true,"id":1,"location":"top","floating":true,"height":34}')), { ok: true, id: 1, location: 'top', floating: true, height: 34 });
    assert.deepEqual(j(P.parseReply('DI_PANEL garbage')), { ok: false });
    assert.deepEqual(j(P.parseReply('')), { ok: false });
});

test('Notch on a floating Pill panel captures its settings once, then attaches it', () => {
    const plan = j(P.decide({ location: 'top', id: 1, floating: true, height: 34 }, none, true, NOTCH));
    assert.deepEqual(plan.capture, { panelId: 1, floating: 1, thickness: 34 });
    assert.deepEqual(plan.apply, { action: 'notch', floating: false, thickness: NOTCH });
    assert.equal(plan.clear, false);
    assert.equal(plan.warn, null);
});

test('Notch on an already attached panel with no record only remembers that it floated', () => {
    const plan = j(P.decide({ location: 'top', id: 1, floating: false, height: NOTCH }, none, true, NOTCH));
    assert.deepEqual(plan.capture, { panelId: 1, floating: 1, thickness: 0 }); // thickness unknown: 0
    assert.equal(plan.apply, null);
});

test('Notch with originals already stored does not capture again', () => {
    const stored = { panelId: 1, floating: 1, thickness: 34 };
    const plan = j(P.decide({ location: 'top', id: 1, floating: true, height: 34 }, stored, true, NOTCH));
    assert.equal(plan.capture, null);
    assert.deepEqual(plan.apply, { action: 'notch', floating: false, thickness: NOTCH });
});

test('originals from another panel do not count: they are captured afresh for this one', () => {
    const other = { panelId: 9, floating: 1, thickness: 34 };
    const plan = j(P.decide({ location: 'top', id: 1, floating: true, height: 54 }, other, true, NOTCH));
    assert.deepEqual(plan.capture, { panelId: 1, floating: 1, thickness: 54 });
});

test('Pill restores the captured settings, and forgets them once the panel matches', () => {
    const stored = { panelId: 1, floating: 1, thickness: 34 };
    const restoring = j(P.decide({ location: 'top', id: 1, floating: false, height: NOTCH }, stored, false, NOTCH));
    assert.deepEqual(restoring.apply, { action: 'restore', floating: true, thickness: 34 });
    assert.equal(restoring.clear, false);
    const done = j(P.decide({ location: 'top', id: 1, floating: true, height: 34 }, stored, false, NOTCH));
    assert.equal(done.clear, true);
    assert.equal(done.apply, null);
});

test('Pill with nothing stored leaves the panel alone', () => {
    const plan = j(P.decide({ location: 'top', id: 1, floating: true, height: 34 }, none, false, NOTCH));
    assert.deepEqual(plan, { warn: null, capture: null, apply: null, clear: false });
});

test('a panel that is not on the top edge is never touched', () => {
    for (const notch of [true, false]) {
        const plan = j(P.decide({ location: 'bottom', id: 1, floating: true, height: 34 }, { panelId: 1, floating: 1, thickness: 34 }, notch, NOTCH));
        assert.match(plan.warn, /not on the top edge/);
        assert.equal(plan.apply, null);
        assert.equal(plan.capture, null);
        assert.equal(plan.clear, false);
    }
});

test('after a change the reply is checked: a restore that did not apply keeps the originals', () => {
    const stored = { panelId: 1, floating: 1, thickness: 34 };
    assert.deepEqual(j(P.evaluateApply({ floating: true, height: 34 }, 'restore', stored, NOTCH)), { clear: true, warn: null });
    const bad = j(P.evaluateApply({ floating: false, height: 34 }, 'restore', stored, NOTCH));
    assert.equal(bad.clear, false);
    assert.match(bad.warn, /original settings kept for a retry/);
});

test('after a change the reply is checked: the notch must be attached at the shell height', () => {
    assert.deepEqual(j(P.evaluateApply({ floating: false, height: NOTCH }, 'notch', none, NOTCH)), { clear: false, warn: null });
    assert.match(P.evaluateApply({ floating: true, height: NOTCH }, 'notch', none, NOTCH).warn, /did not accept the notch settings/);
    assert.match(P.evaluateApply({ floating: false, height: 54 }, 'notch', none, NOTCH).warn, /did not accept the notch settings/);
});

test('syncing is wanted in Notch mode, or while originals are still held', () => {
    assert.equal(P.syncWanted(true, 0), true);
    assert.equal(P.syncWanted(false, 7), true);
    assert.equal(P.syncWanted(false, 0), false);
});

test('the nearest screen to a point, and none when there is no usable screen', () => {
    const two = [{ virtualX: 0, virtualY: 0, width: 1920, height: 1080 }, { virtualX: 1920, virtualY: 0, width: 1280, height: 1024 }];
    assert.equal(P.nearestScreen(two, 100, 100), 0);
    assert.equal(P.nearestScreen(two, 2500, 500), 1);
    assert.equal(P.nearestScreen(two, 5000, 5000), 1); // outside everything: the closest
    assert.equal(P.nearestScreen([], 1, 1), -1);
    assert.equal(P.nearestScreen([{ virtualX: 0, virtualY: 0, width: 0, height: 100 }], 1, 1), -1);
});
