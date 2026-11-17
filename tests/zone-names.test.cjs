const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load } = require('./logic-loader.cjs');
const Z = load('ZoneNames.js');

test('an id is local or the shape the registry accepts', () => {
    assert.equal(Z.validId('local'), true);
    assert.equal(Z.validId('Europe/Lisbon'), true);
    assert.equal(Z.validId('Etc/GMT+5'), true);
    assert.equal(Z.validId(''), false);
    assert.equal(Z.validId('Europe Lisbon'), false);
    assert.equal(Z.validId('a'.repeat(65)), false);
});

test('the fallback city is the last part, readable', () => {
    assert.equal(Z.fallbackCity('America/Argentina/Buenos_Aires'), 'Buenos Aires');
    assert.equal(Z.fallbackCity('UTC'), 'UTC');
    assert.equal(Z.fallbackCity('local'), '');
});
