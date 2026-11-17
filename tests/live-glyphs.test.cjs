const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/LiveGlyphs.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));

test('media wins: a music note, or a film glyph for video', () => {
    assert.equal(ctx.liveKind(true, 'music', ['download']), 'music');
    assert.equal(ctx.liveKind(true, 'video', []), 'video');
    assert.equal(ctx.liveKind(true, 'anything else', ['copy', 'download']), 'music');
});

test('no media: the one kind the jobs share', () => {
    for (const kind of ['download', 'upload', 'delete', 'copy', 'move'])
        assert.equal(ctx.liveKind(false, 'music', [kind, kind]), kind);
    assert.equal(ctx.liveKind(false, 'music', ['download']), 'download');
});

test('no media, mixed kinds: the transfer glyph', () => {
    assert.equal(ctx.liveKind(false, 'music', ['copy', 'download']), 'transfer');
    assert.equal(ctx.liveKind(false, 'music', ['copy', 'copy', 'delete']), 'transfer');
});

test('a generic kind is not a noun, so it reads as mixed', () => {
    assert.equal(ctx.liveKind(false, 'music', ['generic', 'generic']), 'transfer');
    assert.equal(ctx.liveKind(false, 'music', ['generic']), 'transfer');
});

test('every kind has a chain of symbolic names, an unknown one falls to the transfer chain', () => {
    for (const kind of ['music', 'video', 'copy', 'move', 'download', 'upload', 'delete', 'generic', 'transfer']) {
        const chain = j(ctx.chain(kind));
        assert.ok(chain.length >= 2, kind);
        assert.ok(chain.every(n => n.endsWith('-symbolic')), kind);
    }
    assert.deepEqual(j(ctx.chain('nope')), j(ctx.chain('transfer')));
    assert.equal(j(ctx.chain('music'))[0], 'music-note-16th-symbolic');
});
