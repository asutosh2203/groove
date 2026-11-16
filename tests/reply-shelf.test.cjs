const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

function load(name) {
    const src = fs.readFileSync(path.join(__dirname, '../contents/ui/logic', name), 'utf8').replace('.pragma library', '');
    const ctx = vm.createContext({ Math });
    vm.runInContext(src, ctx);
    return ctx;
}
const S = load('ReplyShelf.js');
const j = (v) => JSON.parse(JSON.stringify(v));

test('state machine: closed -> opening -> open -> sending -> closed', () => {
    let s = j(S.initial());
    s = j(S.reduce(s, 'open')); assert.equal(s.phase, 'opening');
    s = j(S.reduce(s, 'opened')); assert.equal(s.phase, 'open');
    s = j(S.reduce(s, 'send')); assert.equal(s.phase, 'sending');
    assert.equal(j(S.reduce(s, 'close')).phase, 'sending', 'a send in flight cannot be closed');
    s = j(S.reduce(s, 'sent')); assert.equal(s.phase, 'closed');
});

test('failure keeps the shelf, shows the error, and editing clears it', () => {
    let s = j(S.reduce(j(S.reduce(j(S.reduce(j(S.reduce(S.initial(), 'open')), 'opened')), 'send')), 'failed', 'gone'));
    assert.deepEqual(s, { phase: 'error', error: 'gone' });
    assert.equal(j(S.reduce(s, 'send')).phase, 'sending', 'retry from error');
    assert.equal(j(S.reduce(s, 'edit')).phase, 'open');
    assert.equal(j(S.reduce(s, 'close')).phase, 'closed');
});

test('transitions that make no sense are ignored', () => {
    const closed = j(S.initial());
    for (const ev of ['opened', 'send', 'sent', 'failed', 'edit']) assert.deepEqual(j(S.reduce(closed, ev)), closed);
    const open = { phase: 'open', error: '' };
    assert.deepEqual(j(S.reduce(open, 'open')), open);
});

test('a send can start while the shelf is still opening', () => {
    assert.equal(j(S.reduce({ phase: 'opening', error: '' }, 'send')).phase, 'sending');
});

test('send needs non-blank text', () => {
    assert.equal(S.canSend(''), false);
    assert.equal(S.canSend('   '), false);
    assert.equal(S.canSend(' hi '), true);
    assert.equal(S.canSend(undefined), false);
});

test('lifetime holds only for focus, text or sending, and only while the shelf is open', () => {
    const open = { phase: 'open', error: '' };
    assert.equal(S.holdsLifetime(S.initial(), true, 'x'), false);
    assert.equal(S.holdsLifetime(open, false, ''), false);
    assert.equal(S.holdsLifetime(open, true, ''), true);
    assert.equal(S.holdsLifetime(open, false, 'x'), true);
    assert.equal(S.holdsLifetime({ phase: 'sending', error: '' }, false, ''), true);
});

test('Esc closes the shelf first, then the popup', () => {
    assert.equal(S.escapeAction({ phase: 'open', error: '' }), 'closeShelf');
    assert.equal(S.escapeAction({ phase: 'opening', error: '' }), 'closeShelf');
    assert.equal(S.escapeAction(S.initial()), 'closePopup');
});

test('pointer leave closes the shelf only when empty and unfocused', () => {
    const open = { phase: 'open', error: '' };
    assert.equal(S.leaveAction(open, '', false), 'close');
    assert.equal(S.leaveAction(open, 'x', false), 'none');
    assert.equal(S.leaveAction(open, '', true), 'none');
    assert.equal(S.leaveAction(S.initial(), '', false), 'none');
});

test('placeholder and symbolic icon name', () => {
    assert.equal(S.placeholder('Message Bob', 'Reply to Bob…'), 'Message Bob');
    assert.equal(S.placeholder('  ', 'Reply to Bob…'), 'Reply to Bob…');
    assert.equal(S.placeholder(undefined, 'Reply to Bob…'), 'Reply to Bob…');
    assert.equal(S.symbolicName('mail-send'), 'mail-send-symbolic');
    assert.equal(S.symbolicName('mail-send-symbolic'), 'mail-send-symbolic');
    assert.equal(S.symbolicName(''), '');
});

test('the dwell fires once per hover session', () => {
    const closed = j(S.initial());
    assert.equal(S.shouldDwell(closed, true, true, false), true);
    assert.equal(S.shouldDwell(closed, true, true, true), false, 'spent: no reopen after Esc while still hovering');
    assert.equal(S.shouldDwell(closed, false, true, false), false);
    assert.equal(S.shouldDwell(closed, true, false, false), false);
    assert.equal(S.shouldDwell({ phase: 'open', error: '' }, true, true, false), false);
});
