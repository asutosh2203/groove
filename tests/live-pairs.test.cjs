const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/LivePairs.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const keys = (cards) => JSON.parse(JSON.stringify(cards.map(c => c.key)));
const card = (key, priority, recency) => ({ key, priority, recency });

test('rank: priority, then recency, then key', () => {
    const r = ctx.rank([card('m', 100, 5), card('j1', 200, 1), card('j2', 200, 9), card('a', 100, 5)]);
    assert.deepEqual(keys(r), ['j2', 'j1', 'a', 'm']);
});

test('rank does not mutate its input', () => {
    const input = [card('b', 100, 1), card('a', 200, 1)];
    ctx.rank(input);
    assert.deepEqual(keys(input), ['b', 'a']);
});

test('one or two cards: one pair, no chip, no back', () => {
    for (const n of [1, 2]) {
        const v = ctx.view(Array.from({ length: n }, (_, i) => card('c' + i, 100, i)), 0);
        assert.equal(v.cards.length, n);
        assert.equal(v.more, 0);
        assert.equal(v.canBack, false);
    }
});

test('five cards: +3 then +1 then none, back from pair 1', () => {
    const cards = [1, 2, 3, 4, 5].map(i => card('c' + i, 100, i));
    const p0 = ctx.view(cards, 0), p1 = ctx.view(cards, 1), p2 = ctx.view(cards, 2);
    assert.deepEqual(keys(p0.cards), ['c5', 'c4']);
    assert.equal(p0.more, 3);
    assert.deepEqual(keys(p1.cards), ['c3', 'c2']);
    assert.equal(p1.more, 1);
    assert.equal(p1.canBack, true);
    assert.deepEqual(keys(p2.cards), ['c1']);
    assert.equal(p2.more, 0);
});

test('clamp: a pair that ended falls back to the previous one, then the first', () => {
    assert.equal(ctx.clampPair(2, 5), 2);
    assert.equal(ctx.clampPair(2, 4), 1);
    assert.equal(ctx.clampPair(2, 1), 0);
    assert.equal(ctx.clampPair(3, 0), 0);
    assert.equal(ctx.clampPair(-1, 4), 0);
});

test('a higher-priority arrival keeps the pair index', () => {
    const cards = [card('a', 100, 1), card('b', 100, 2), card('c', 100, 3), card('d', 100, 4)];
    assert.equal(ctx.view(cards, 1).pairIndex, 1);
    const more = cards.concat([card('crit', 200, 9)]);
    const v = ctx.view(more, 1);
    assert.equal(v.pairIndex, 1);
    assert.deepEqual(keys(v.cards), ['c', 'b']);
});
