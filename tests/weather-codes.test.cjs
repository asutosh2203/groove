const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../contents/ui/weather/WeatherCodes.js'), 'utf8');
const codes = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), codes);

test('WMO codes map to icon keys with day/night variants', () => {
    assert.equal(codes.iconKey(0, true), 'clear-day');
    assert.equal(codes.iconKey(0, false), 'clear-night');
    assert.equal(codes.iconKey(2, 0), 'partly-cloudy-night');
    assert.equal(codes.iconKey(3, true), 'overcast');
    assert.equal(codes.iconKey(48, true), 'fog');
    assert.equal(codes.iconKey(53, true), 'drizzle');
    assert.equal(codes.iconKey(66, true), 'sleet');
    assert.equal(codes.iconKey(63, true), 'rain');
    assert.equal(codes.iconKey(75, true), 'snow');
    assert.equal(codes.iconKey(81, false), 'partly-cloudy-night-rain');
    assert.equal(codes.iconKey(86, true), 'partly-cloudy-day-snow');
    assert.equal(codes.iconKey(99, true), 'thunderstorms-rain');
    assert.equal(codes.iconKey(1234, true), 'not-available');
});

test('temperature display rounds and converts', () => {
    assert.equal(codes.displayTemperature(21.5, false), '22°C');
    assert.equal(codes.displayTemperature(0, true), '32°F');
    assert.equal(codes.displayTemperature(NaN, false), '--°C');
    assert.deepEqual(codes.temperatureParts(18.6, true), { value: '65', unit: '°F' });
});

test('forecast url uses encoded-safe coordinates', () => {
    assert.equal(codes.forecastUrl(52.52437, 13.41053), 'https://www.yr.no/en/forecast/daily-table/52.5244,13.4105');
});

test('validCurrent rejects malformed responses', () => {
    assert.equal(codes.validCurrent({ current: { temperature_2m: 3, weather_code: 1 } }), true);
    assert.equal(codes.validCurrent({ current: { temperature_2m: '3', weather_code: 1 } }), false);
    assert.equal(codes.validCurrent(null), false);
});
