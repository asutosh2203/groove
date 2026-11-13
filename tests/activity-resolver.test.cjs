const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// D-38: highest first, Critical notification > keyboard layout announcement > Normal notification > job > media > idle.
// A Low notification is not an activity. D-13 (the previous activity returns) and D-35 (idle after 30 s paused) are
// unchanged. Pre-emption is tested here without a shell.
const source = fs.readFileSync(path.join(__dirname, '../contents/ui/logic/ActivityResolver.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const ctx = vm.createContext({ Number, isFinite, Math });
vm.runInContext(source, ctx);
const R = ctx;
const j = (v) => JSON.parse(JSON.stringify(v));
const P = j(vm.runInContext('priority', ctx));

// A shell's providers as main.qml declares them. `notice` is "none" | "low" | "normal" | "critical"; a Low notification is
// never active (the service's rule, tested with Notifications.js).
function shell(active = {}, notice = 'none') {
    const noticeActive = notice === 'normal' || notice === 'critical';
    return [
        { key: 'keyboard', active: !!active.keyboard, priority: P.keyboard, autoCloseMs: 3000 },
        { key: 'job', active: !!active.job, priority: P.job, autoCloseMs: 3000 },
        { key: 'notice', active: noticeActive, priority: R.noticePriority(notice), autoCloseMs: 4000 },
        { key: 'media', active: !!active.media, priority: P.media, autoCloseMs: 3000 },
        { key: 'idle', active: true, priority: P.idle, autoCloseMs: 3000 },
    ];
}
const shown = (providers) => R.keyOf(R.highest(providers));

test('the priority table: Critical > keyboard > Normal > job > media > idle', () => {
    assert.ok(P.noticeCritical > P.keyboard && P.keyboard > P.noticeNormal && P.noticeNormal > P.job && P.job > P.media && P.media > P.idle);
    assert.equal(R.noticePriority('critical'), P.noticeCritical);
    assert.equal(R.noticePriority('normal'), P.noticeNormal);
});

test('a Low notification (or anything else) has no priority: it is not an activity', () => {
    for (const kind of ['low', 'none', undefined, null, '', 'urgent', 4, 2])
        assert.equal(R.noticePriority(kind), P.idle, String(kind));
});

test('nothing active shows idle', () => {
    assert.equal(shown(shell({})), 'idle');
    assert.equal(shown([]), 'idle');
});

test('a notification pre-empts media, and media returns when the notification ends (D-13)', () => {
    assert.equal(shown(shell({ media: true })), 'media');
    assert.equal(shown(shell({ media: true }, 'normal')), 'notice');
    assert.equal(shown(shell({ media: true }, 'critical')), 'notice');
    assert.equal(shown(shell({ media: true }, 'none')), 'media');
});

test('a paused player that gave way to idle (D-35) stays out of the way of everything else', () => {
    assert.equal(shown(shell({ media: false })), 'idle');
    assert.equal(shown(shell({ media: false }, 'normal')), 'notice');
    assert.equal(shown(shell({ media: true })), 'media'); // playing again takes it back at once
});

test('a Low notification never pre-empts anything: media, a job and a keyboard announcement stay up', () => {
    assert.equal(shown(shell({}, 'low')), 'idle'); // and no popup: it is not an activity
    assert.equal(shown(shell({ media: true }, 'low')), 'media');
    assert.equal(shown(shell({ job: true }, 'low')), 'job');
    assert.equal(shown(shell({ keyboard: true }, 'low')), 'keyboard');
    assert.equal(shown(shell({ keyboard: true, job: true, media: true }, 'low')), 'keyboard');
});

test('a Normal notification beats a job and media but yields to a keyboard announcement', () => {
    assert.equal(shown(shell({ job: true, media: true }, 'normal')), 'notice');
    assert.equal(shown(shell({ keyboard: true, job: true, media: true }, 'normal')), 'keyboard');
    assert.equal(shown(shell({ keyboard: true }, 'normal')), 'keyboard');
});

test('a Critical notification beats everything, the keyboard announcement included', () => {
    assert.equal(shown(shell({ keyboard: true, job: true, media: true }, 'critical')), 'notice');
    assert.equal(shown(shell({ keyboard: true }, 'critical')), 'notice');
});

test('a keyboard announcement beats a job and media', () => {
    assert.equal(shown(shell({ keyboard: true, job: true, media: true })), 'keyboard');
    assert.equal(shown(shell({ job: true, media: true })), 'job');
});

test('equal priorities: the first provider wins; inactive and missing providers are skipped', () => {
    assert.equal(R.highest([{ key: 'a', active: true, priority: 5 }, { key: 'b', active: true, priority: 5 }]).key, 'a');
    assert.equal(R.highest([null, undefined, { key: 'x', active: false, priority: 9 }]), null);
    assert.equal(R.highest([]), null);
});

test('asking for a specific activity gets it only while it is active', () => {
    const ps = shell({ media: true }, 'normal');
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
    const base = { requestedExists: true, requestedActive: true, hasActivity: true, activityPopupOpen: false, popupTimerRunning: false, nextPriority: P.noticeNormal, shownPriority: P.media };
    assert.equal(R.bumpDecision(base), 'show');
    assert.equal(R.bumpDecision({ ...base, requestedActive: false }), 'ignore'); // e.g. a Low notice: its provider is inactive
    assert.equal(R.bumpDecision({ ...base, hasActivity: false }), 'ignore');
    assert.equal(R.bumpDecision({ ...base, requestedExists: false, requestedActive: false }), 'show'); // "auto" has no provider to check
});

test('bump: a lower-priority arrival does not replace a higher popup that is still timing, it extends it', () => {
    const open = { requestedExists: true, requestedActive: true, hasActivity: true, activityPopupOpen: true, popupTimerRunning: true, shownPriority: P.noticeCritical };
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media }), 'extend');
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.noticeCritical }), 'show'); // equal replaces
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media, popupTimerRunning: false }), 'show'); // not timing: replace
    assert.equal(R.bumpDecision({ ...open, nextPriority: P.media, activityPopupOpen: false }), 'show'); // not an activity popup
});

test('bump: a Normal notification does not replace an open keyboard announcement, a Critical one does', () => {
    const open = { requestedExists: true, requestedActive: true, hasActivity: true, activityPopupOpen: true, popupTimerRunning: true, shownPriority: P.keyboard };
    assert.equal(R.bumpDecision({ ...open, nextPriority: R.noticePriority('normal') }), 'extend');
    assert.equal(R.bumpDecision({ ...open, nextPriority: R.noticePriority('critical') }), 'show');
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

// --- the old order, kept here only to document exactly what D-38 changes ---------------------------------------------

test('D-38 changes the shown activity in exactly six of the 32 combinations, and each is intended', () => {
    // Before D-38: keyboard 350, job 300, media 100; any notice with KDE urgency >= 2 (Normal and Critical) 400, a Low one 200.
    const old = { keyboard: 350, job: 300, media: 100, noticeUrgent: 400, noticeLow: 200 };
    const oldNotice = { low: old.noticeLow, normal: old.noticeUrgent, critical: old.noticeUrgent };
    const differing = [];
    let combinations = 0;
    for (const keyboard of [false, true]) for (const job of [false, true]) for (const notice of ['none', 'low', 'normal', 'critical']) for (const media of [false, true]) {
        combinations++;
        const oldProviders = [
            { key: 'keyboard', active: keyboard, priority: old.keyboard }, { key: 'job', active: job, priority: old.job },
            { key: 'notice', active: notice !== 'none', priority: oldNotice[notice] || 0 }, { key: 'media', active: media, priority: old.media },
            { key: 'idle', active: true, priority: 0 },
        ];
        const before = shown(oldProviders);
        const after = shown(shell({ keyboard, job, media }, notice));
        if (before !== after) differing.push({ keyboard, job, notice, media, before, after });
    }
    assert.equal(combinations, 32);
    assert.deepEqual(differing, [
        { keyboard: false, job: false, notice: 'low', media: false, before: 'notice', after: 'idle' },
        { keyboard: false, job: false, notice: 'low', media: true, before: 'notice', after: 'media' },
        { keyboard: true, job: false, notice: 'normal', media: false, before: 'notice', after: 'keyboard' },
        { keyboard: true, job: false, notice: 'normal', media: true, before: 'notice', after: 'keyboard' },
        { keyboard: true, job: true, notice: 'normal', media: false, before: 'notice', after: 'keyboard' },
        { keyboard: true, job: true, notice: 'normal', media: true, before: 'notice', after: 'keyboard' },
    ]);
    // Intended: a Low notice used to show a popup; a Normal notice used to out-rank the keyboard announcement.
    assert.ok(differing.every((d) => (d.notice === 'low' && d.before === 'notice') || (d.notice === 'normal' && d.keyboard && d.after === 'keyboard')));
});
