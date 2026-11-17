const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/WidgetState.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const NOW = 10 * 3600 * 1000;
const base = { needsSetup: false, hasData: true, busy: false, failing: false, updatedMs: NOW - 60000, now: NOW };

test('states', () => {
    assert.equal(ctx.state({ ...base, needsSetup: true, hasData: false }), 'needsSetup');
    assert.equal(ctx.state({ ...base, hasData: false }), 'loading');
    assert.equal(ctx.state({ ...base, hasData: false, busy: true, failing: true }), 'loading');
    assert.equal(ctx.state({ ...base, hasData: false, failing: true }), 'error');
    assert.equal(ctx.state(base), 'ready');
    assert.equal(ctx.state({ ...base, failing: true }), 'stale');
    assert.equal(ctx.state({ ...base, updatedMs: NOW - 61 * 60000 }), 'stale');
    assert.equal(ctx.state({ ...base, updatedMs: NOW - 59 * 60000 }), 'ready');
});

test('stale age is rounded down, at least a minute', () => {
    assert.deepEqual(j(ctx.age(NOW - 5000, NOW)), { unit: 'minute', n: 1 });
    assert.deepEqual(j(ctx.age(NOW - 59 * 60000, NOW)), { unit: 'minute', n: 59 });
    assert.deepEqual(j(ctx.age(NOW - 2 * 3600000 - 59000, NOW)), { unit: 'hour', n: 2 });
    assert.deepEqual(j(ctx.age(NOW - 23.9 * 3600000, NOW)), { unit: 'hour', n: 23 });
    assert.deepEqual(j(ctx.age(NOW - 50 * 3600000, NOW)), { unit: 'day', n: 2 });
});
