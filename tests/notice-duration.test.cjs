const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/NoticeDuration.js'), 'utf8');
const ctx = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), ctx);
const ms = (requested, setting, urgency) => ctx.effectiveDurationMs(requested, setting, urgency);

const NORMAL = 2;
const CRITICAL = 4;

// [requested, setting, urgency, expected, why]
const table = [
    [2500, 4000, NORMAL, 2500, 'apps may shorten'],
    [1000, 4000, NORMAL, 2000, '2 s readability floor'],
    [3999, 4000, NORMAL, 3999, 'just under the setting'],
    [4000, 4000, NORMAL, 4000, 'equal to the setting'],
    [30000, 4000, NORMAL, 4000, 'apps never lengthen'],
    [-1, 4000, NORMAL, 4000, 'server default'],
    [0, 4000, NORMAL, 4000, 'never expires'],
    [NaN, 4000, NORMAL, 4000, 'NaN'],
    [undefined, 4000, NORMAL, 4000, 'undefined'],
    [null, 4000, NORMAL, 4000, 'null'],
    ['abc', 4000, NORMAL, 4000, 'garbage string'],
    [-500, 4000, NORMAL, 4000, 'other negatives'],
    [2500, 10000, NORMAL, 2500, 'shorter than a long setting'],
    [1000, 2000, NORMAL, 2000, 'floor equals the setting'],
    [-1, 4000, CRITICAL, 6000, 'critical raises a short setting to 6 s'],
    [1000, 4000, CRITICAL, 6000, 'critical beats an app shortening'],
    [30000, 4000, CRITICAL, 6000, 'critical with a long request'],
    [-1, 10000, CRITICAL, 10000, 'critical keeps a longer setting'],
    [-1, 15000, CRITICAL, 15000, 'critical at the ceiling'],
    [2500, 15000, CRITICAL, 6000, 'critical with a shortened request'],
    [-1, 4000, 1, 4000, 'low urgency gets no floor'],
    [-1, 4000, undefined, 4000, 'unknown urgency is not critical'],
];

for (const [requested, setting, urgency, expected, why] of table) {
    test(`${String(requested)} ms / setting ${setting} / urgency ${String(urgency)} -> ${expected} (${why})`, () => {
        assert.equal(ms(requested, setting, urgency), expected);
    });
}

test('never above 15 s, whatever the setting', () => {
    assert.equal(ms(-1, 60000, NORMAL), 15000);
    assert.equal(ms(-1, 60000, CRITICAL), 15000);
});

test('a bad setting falls back to the 2 s floor', () => {
    assert.equal(ms(-1, NaN, NORMAL), 2000);
    assert.equal(ms(-1, undefined, NORMAL), 2000);
});
