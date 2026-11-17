const assert = require('node:assert/strict');
const { test } = require('node:test');
const { load, j } = require('./logic-loader.cjs');
const G = load('Geocoding.js');

test('the request carries the language and the escaped, trimmed query', () => {
    const u = G.url('  São Paulo ', 'pt_BR');
    assert.ok(u.startsWith('https://geocoding-api.open-meteo.com/v1/search?'));
    assert.ok(u.includes('language=pt&'));
    assert.ok(u.endsWith('name=S%C3%A3o%20Paulo'));
});

test('a query needs two characters', () => {
    assert.equal(G.validQuery(' a '), false);
    assert.equal(G.validQuery('Oslo'), true);
});

test('rows read as text, name and coordinates; bad rows and bodies are dropped or null', () => {
    const body = JSON.stringify({ results: [{ name: 'Oslo', admin1: 'Oslo', country: 'Norway', latitude: 59.9, longitude: 10.7 }, { name: 'Bad' }, { name: 'Lisbon', country: 'Portugal', latitude: 38.7, longitude: -9.1 }] });
    assert.deepEqual(j(G.parse(body)), [{ text: 'Oslo, Oslo, Norway', name: 'Oslo', lat: 59.9, lon: 10.7 }, { text: 'Lisbon, Portugal', name: 'Lisbon', lat: 38.7, lon: -9.1 }]);
    assert.deepEqual(j(G.parse('{}')), []);
    assert.equal(G.parse('nope'), null);
    assert.equal(G.parse('{"results": 5}'), null);
});
