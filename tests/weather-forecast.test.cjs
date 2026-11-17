const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
const load = (f) => vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/' + f), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
load('WeatherForecast.js');
load('WeatherCodes.js');
const j = (v) => JSON.parse(JSON.stringify(v));
const OFFSET = 3600; // a location at UTC+1
const iso = (s) => Date.parse(s + 'Z') - OFFSET * 1000; // local ISO text -> epoch ms
const hoursFrom = (start, n) => Array.from({ length: n }, (_, i) => new Date(Date.parse(start + ':00Z') + i * 3600000).toISOString().slice(0, 16));
const response = () => {
    const time = hoursFrom('2026-11-17T00', 72);
    return {
        utc_offset_seconds: OFFSET,
        daily: {
            time: ['2026-11-17', '2026-11-18', '2026-11-19', '2026-11-20', '2026-11-21', '2026-11-22'],
            weather_code: [3, 61, 0, 2, 71, 95], temperature_2m_max: [27, 20, 19, 18, 2, 1], temperature_2m_min: [18, 12, 11, 10, -3, -4],
            sunrise: ['2026-11-17T07:10', '2026-11-18T07:11', '2026-11-19T07:12', '2026-11-20T07:13', '2026-11-21T07:14', '2026-11-22T07:15'],
            sunset: ['2026-11-17T17:58', '2026-11-18T17:57', '2026-11-19T17:56', '2026-11-20T17:55', '2026-11-21T17:54', '2026-11-22T17:53']
        },
        hourly: { time, temperature_2m: time.map((_, i) => 10 + (i % 24) / 2), weather_code: time.map(() => 3), is_day: time.map((t) => { const h = Number(t.slice(11, 13)); return h >= 7 && h < 18 ? 1 : 0; }) }
    };
};
const fc = () => j(ctx.parse(response()));
const NOW = iso('2026-11-17T16:20');

test('request asks for current, daily and hourly in one go', () => {
    const q = vm.runInContext('FORECAST_QUERY', ctx);
    for (const word of ['current=', 'daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset', 'hourly=temperature_2m,weather_code,is_day', 'forecast_days=6', 'timezone=auto'])
        assert.ok(q.includes(word), word);
});

test('parse turns the location\'s local times into instants', () => {
    const f = fc();
    assert.equal(f.daily.length, 6);
    assert.equal(f.daily[0].sunset, iso('2026-11-17T17:58'));
    assert.equal(f.daily[0].dow, 2); // Tuesday
    assert.equal(f.hourly[0].ms, iso('2026-11-17T00:00'));
    assert.equal(f.hourly.length, 72);
    assert.equal(f.hourly[8].isDay, true);
    assert.equal(ctx.parse({}), null);
    assert.equal(ctx.parse({ utc_offset_seconds: 'x', daily: { time: [] }, hourly: { time: [] } }), null);
});

test('rows with a missing value are left out', () => {
    const r = response();
    r.daily.temperature_2m_max[1] = null;
    r.hourly.temperature_2m[0] = null;
    const f = j(ctx.parse(r));
    assert.equal(f.daily.length, 5);
    assert.equal(f.hourly.length, 71);
});

test('trim keeps the hours from one hour ago, at most 48', () => {
    const t = j(ctx.trim(ctx.parse(response()), NOW));
    assert.equal(t.hourly.length, 48);
    assert.equal(t.hourly[0].ms, iso('2026-11-17T16:00'));
    assert.equal(t.daily.length, 6);
});

test('today and the day columns start with today', () => {
    const f = ctx.parse(response());
    assert.equal(j(ctx.today(f, NOW)).max, 27);
    const d = j(ctx.days(f, NOW, 5));
    assert.equal(d.length, 5);
    assert.equal(d[0].isToday, true);
    assert.deepEqual(d.map(x => x.max), [27, 20, 19, 18, 2]);
    // after the location's midnight it is the next day, whatever the system zone says
    assert.equal(j(ctx.days(f, iso('2026-11-18T00:30'), 5))[0].max, 20);
});

test('next sun event: sunset in the day, sunrise at night', () => {
    const f = ctx.parse(response());
    assert.deepEqual(j(ctx.nextSun(f, NOW)), { kind: 'sunset', ms: iso('2026-11-17T17:58') });
    assert.equal(j(ctx.nextSun(f, iso('2026-11-17T18:00'))).kind, 'sunrise');
    assert.equal(j(ctx.nextSun(f, iso('2026-11-17T18:00'))).ms, iso('2026-11-18T07:11'));
    assert.equal(j(ctx.nextSun(f, iso('2026-11-17T05:00'))).kind, 'sunrise');
    assert.equal(ctx.nextSun(ctx.parse(response()), iso('2026-11-23T00:00')), null);
});

const current = { t: 25, code: 3, isDay: true };

test('hourly strip: Now first, then the hours, with the sun column between the hours around its time', () => {
    const f = ctx.parse(response());
    const s = j(ctx.strip(f, NOW, current, 6));
    assert.equal(s[1].ms, iso('2026-11-17T17:00'));
    assert.equal(s[2].kind, 'sun');
    assert.equal(s[2].ms, iso('2026-11-17T17:58'));
    assert.equal(s[2].sun, 'sunset');
    assert.equal(s[3].ms, iso('2026-11-17T18:00'));
    assert.deepEqual(s.map(c => c.ms), [...s.map(c => c.ms)].sort((a, b) => a - b));
});

test('the sun column is left out when it falls beyond the strip, and the count is respected', () => {
    const f = ctx.parse(response());
    const short = j(ctx.strip(f, NOW, current, 2));
    assert.deepEqual(short.map(c => c.kind), ['now', 'hour']);
    assert.equal(j(ctx.strip(f, NOW, current, 1)).length, 1);
    assert.equal(j(ctx.strip(f, NOW, current, 12)).filter(c => c.kind === 'sun').length, 1);
    assert.equal(j(ctx.strip(f, NOW, current, 12)).length, 12);
});

test('at night the sun column is a sunrise', () => {
    const f = ctx.parse(response());
    const night = iso('2026-11-17T22:20');
    const s = j(ctx.strip(f, night, { t: 12, code: 0, isDay: false }, 12));
    const sun = s.find(c => c.kind === 'sun');
    assert.equal(sun.sun, 'sunrise');
    assert.equal(sun.ms, iso('2026-11-18T07:11'));
});

test('temperature rounding and units', () => {
    assert.equal(ctx.deg(26.6, false), '27°');
    assert.equal(ctx.deg(0, true), '32°');
    assert.equal(ctx.deg(-0.4, false), '0°');
});

test('detail line for both settings', () => {
    const o = { condition: 'Cloudy', today: { max: 27.2, min: 18.4 }, sun: { kind: 'sunset', ms: 1000 }, fahrenheit: false, offset: 0 };
    const hm = (ms, off) => '17:58';
    assert.deepEqual(j(ctx.detail('highlow', o, hm)), { head: 'Cloudy · 27° / 18°', glyph: '', tail: '' });
    assert.deepEqual(j(ctx.detail('sun', o, hm)), { head: 'Cloudy · ', glyph: 'sunset', tail: '17:58' });
    assert.deepEqual(j(ctx.detail('sun', { ...o, sun: { kind: 'sunrise', ms: 1 } }, hm)).glyph, 'sunrise');
    assert.equal(j(ctx.detail('highlow', { ...o, fahrenheit: true }, hm)).head, 'Cloudy · 81° / 65°');
});

test('detail line falls back to the condition when the data is missing', () => {
    const o = { condition: 'Cloudy', today: null, sun: null, fahrenheit: false, offset: 0 };
    assert.equal(j(ctx.detail('highlow', o, () => '')).head, 'Cloudy');
    assert.equal(j(ctx.detail('sun', o, () => '')).head, 'Cloudy');
    assert.equal(j(ctx.detail('highlow', { ...o, condition: '' }, () => '')).head, '');
});

test('the peek shows the other value', () => {
    assert.equal(ctx.other('highlow'), 'sun');
    assert.equal(ctx.other('sun'), 'highlow');
});

test('condition keys follow the WMO codes', () => {
    assert.equal(ctx.conditionKey(0, true), 'sunny');
    assert.equal(ctx.conditionKey(0, false), 'clear');
    assert.equal(ctx.conditionKey(3, true), 'cloudy');
    assert.equal(ctx.conditionKey(61, true), 'rain');
    assert.equal(ctx.conditionKey(95, true), 'thunderstorm');
    assert.equal(ctx.conditionKey(999, true), '');
});

test('one fetch per location: duplicates and the island\'s own are dropped', () => {
    const island = ctx.locationKey(48.8566, 2.3522);
    const list = [{ name: 'Oslo', lat: 59.9139, lon: 10.7522 }, { name: 'Paris again', lat: 48.8566, lon: 2.35221 }, { name: 'Oslo 2', lat: 59.91390, lon: 10.7522 }, { name: 'Rome', lat: 41.9, lon: 12.5 }];
    assert.deepEqual(j(ctx.uniqueLocations(list, island)).map(l => l.name), ['Oslo', 'Rome']);
    assert.deepEqual(j(ctx.uniqueLocations([{ name: 'P', lat: 48.8566, lon: 2.3522 }], island)), []);
});

test('the cache keeps the four most recent locations and ignores unreadable text', () => {
    const entry = (ms) => ({ updatedMs: ms, current: { t: 1, code: 3, isDay: true }, forecast: null });
    let text = '';
    for (let i = 1; i <= 5; i++) text = ctx.cacheWrite(text, 'k' + i, entry(i));
    assert.equal(ctx.cacheRead(text, 'k1'), null);
    assert.equal(j(ctx.cacheRead(text, 'k5')).updatedMs, 5);
    assert.equal(Object.keys(JSON.parse(text).entries).length, 4);
    text = ctx.cacheWrite(text, 'k2', entry(9));
    assert.equal(j(ctx.cacheRead(text, 'k2')).updatedMs, 9);
    assert.equal(ctx.cacheRead('garbage', 'k'), null);
    assert.equal(ctx.cacheRead('{"version":2,"entries":{}}', 'k'), null);
    assert.equal(j(ctx.cacheRead(ctx.cacheWrite('garbage', 'a', entry(1)), 'a')).updatedMs, 1);
    assert.equal(ctx.cacheRead(JSON.stringify({ version: 1, entries: { a: { updatedMs: 1 } } }), 'a'), null);
});
