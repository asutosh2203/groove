const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Characterised against the controller and bump code as they were before they moved. The scenarios below are the
// product rules: notifications pre-empt media and media returns (D-13), a paused player gives way to idle (D-35), jobs
// and keyboard announcements slot in by priority.
const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/ActivityResolver.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const ctx = vm.createContext({ Number, isFinite, Math });
vm.runInContext(source, ctx);
const R = ctx;
const P = j0(vm.runInContext('priority', ctx));
const j = (v) => JSON.parse(JSON.stringify(v));
function j0(v) { return JSON.parse(JSON.stringify(v)); }

// A shell's providers, as main.qml declares them, with only the given ones active. KDE urgency: Low 1, Normal 2, Critical 4.
function shell(active = {}, urgency = 2) {
    return [
        { key: 'keyboard', active: !!active.keyboard, priority: P.keyboard, autoCloseMs: 3000 },
        { key: 'job', active: !!active.job, priority: P.job, autoCloseMs: 3000 },
        { key: 'notice', active: !!active.notice, priority: R.noticePriority(urgency), autoCloseMs: 4000 },
        { key: 'media', active: !!active.media, priority: P.media, autoCloseMs: 3000 },
        { key: 'idle', active: true, priority: P.idle, autoCloseMs: 3000 },
    ];
}
const shown = (providers) => R.keyOf(R.highest(providers));

test('the priority table: top-tier notice > keyboard > job > low-urgency notice > media > idle', () => {
    assert.ok(P.noticeUrgent > P.keyboard && P.keyboard > P.job && P.job > P.notice && P.notice > P.media && P.media > P.idle);
    assert.equal(R.noticePriority(4), P.noticeUrgent); // Critical
    assert.equal(R.noticePriority(2), P.noticeUrgent); // Normal too: the rule is >= 2 (quirk, logged for B1)
    assert.equal(R.noticePriority(1), P.notice); // only Low gets the middle tier
    assert.equal(R.noticePriority(undefined), P.notice);
});

test('nothing active shows idle', () => {
    assert.equal(shown(shell({})), 'idle');
    assert.equal(shown([]), 'idle');
});

test('a notification pre-empts media, and media returns when the notification ends (D-13)', () => {
    assert.equal(shown(shell({ media: true })), 'media');
    assert.equal(shown(shell({ media: true, notice: true }, 1)), 'notice');
    assert.equal(shown(shell({ media: true, notice: false }, 1)), 'media');
});

test('a paused player that gave way to idle (D-35) stays out of the way of everything else', () => {
    assert.equal(shown(shell({ media: false })), 'idle');
    assert.equal(shown(shell({ media: false, notice: true }, 1)), 'notice');
    assert.equal(shown(shell({ media: true })), 'media'); // playing again takes it back at once
});

test('a job beats a low-urgency notification; a Normal or Critical one beats the job', () => {
    assert.equal(shown(shell({ job: true, notice: true }, 1)), 'job');
    assert.equal(shown(shell({ job: true, notice: true }, 2)), 'notice'); // Normal already pre-empts a job
    assert.equal(shown(shell({ job: true, notice: true }, 4)), 'notice');
});

test('a keyboard layout announcement beats a job and a low-urgency notice, but not a Normal or Critical one', () => {
    assert.equal(shown(shell({ keyboard: true, job: true, notice: true, media: true }, 1)), 'keyboard');
    assert.equal(shown(shell({ keyboard: true, notice: true }, 2)), 'notice');
    assert.equal(shown(shell({ keyboard: true, notice: true }, 4)), 'notice');
});

test('equal priorities: the first provider wins; inactive and missing providers are skipped', () => {
    assert.equal(R.highest([{ key: 'a', active: true, priority: 5 }, { key: 'b', active: true, priority: 5 }]).key, 'a');
    assert.equal(R.highest([null, undefined, { key: 'x', active: false, priority: 9 }]), null);
    assert.equal(R.highest([]), null);
});

test('asking for a specific activity gets it only while it is active', () => {
    const ps = shell({ media: true, notice: true }, 1);
    const cur = R.highest(ps);
    assert.equal(R.pick(ps, cur, 'media').key, 'media'); // asked for and active: it, even though notice is higher
    assert.equal(R.pick(ps, cur, 'job').key, 'notice'); // asked for but inactive: the current one
    assert.equal(R.pick(ps, cur, 'auto').key, 'notice');
    assert.equal(R.pick(ps, cur, undefined).key, 'notice');
    assert.equal(R.pick(ps, cur, 'nope').key, 'notice');
    assert.equal(R.keyOf(null), 'idle');
    assert.equal(R.priorityOf(null), 0);
});

test('bump: a requested activity that is not active, or no activity at all, is ignored', () => {
    const base = { requestedExists: true, requestedActive: true, hasActivity: true, activityPopupOpen: false, popupTimerRunning: false, nextPriority: P.notice, shownPriority: P.media };
    assert.equal(R.bumpDecision(base), 'show');
    assert.equal(R.bumpDecision({ ...base, requestedActive: false }), 'ignore');
    assert.equal(R.bumpDecision({ ...base, hasActivity: false }), 'ignore');
    assert.equal(R.bumpDecision({ ...base, requestedExists: false, requestedActive: false }), 'show'); // "auto" has no provider to check
});

test('bump: a lower-priority arrival does not replace a higher popup that is still timing, it extends it', () => {
    const open = { requestedExists: true, requestedActive: true, hasActivity: true, activityPopupOpen: true, popupTimerRunning: true, shownPriority: P.noticeUrgent };
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media }), 'extend');
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.noticeUrgent }), 'show'); // equal replaces
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media, popupTimerRunning: false }), 'show'); // not timing: replace
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media, activityPopupOpen: false }), 'show'); // not an activity popup
});

test('which model row an activity reads', () => {
    assert.equal(R.rowFor('notice', 2, 5), 2);
    assert.equal(R.rowFor('notice', -1, 5), 5); // no notice row: fall back to a job
    assert.equal(R.rowFor('job', 2, 5), 5);
    assert.equal(R.rowFor('media', 2, 5), 5); // a job row wins by default
    assert.equal(R.rowFor('media', 2, -1), 2);
    assert.equal(R.rowFor('media', -1, -1), 0);
});

test('the auto-close time is at least a second and 3 s when unknown', () => {
    assert.equal(R.autoCloseMs({ autoCloseMs: 4000 }), 4000);
    assert.equal(R.autoCloseMs({ autoCloseMs: 200 }), 1000);
    assert.equal(R.autoCloseMs({ autoCloseMs: 'x' }), 3000);
    assert.equal(R.autoCloseMs(null), 3000);
});

test('display fields fall back when there is no provider', () => {
    assert.equal(R.field(null, 'progressTo', 1), 1);
    assert.equal(R.field({ progressTo: 100 }, 'progressTo', 1), 100);
    assert.deepEqual(j(R.field({ key: 'x' }, 'key', null)), 'x');
});
