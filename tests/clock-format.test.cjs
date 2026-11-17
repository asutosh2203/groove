const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/logic/ClockFormat.js'), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const at = (iso) => Date.parse(iso);
const KOLKATA = 19800, NEW_YORK_STD = -18000, NEW_YORK_DST = -14400, TOKYO = 32400, BERLIN_STD = 3600, BERLIN_DST = 7200;

test('offsets parse from Plasma\'s text', () => {
    assert.equal(ctx.parseOffset('UTC+05:30'), 19800);
    assert.equal(ctx.parseOffset('UTC-05:00'), -18000);
    assert.equal(ctx.parseOffset('UTC-5'), -18000);
    assert.equal(ctx.parseOffset('UTC+12:45'), 45900);
    assert.equal(ctx.parseOffset('UTC'), 0);
    assert.equal(ctx.parseOffset('Europe/Berlin'), NaN);
    assert.equal(ctx.parseOffset(''), 0);
});

test('time: 24-hour, 12-hour and following the locale', () => {
    const t = at('2026-11-17T20:00:00Z');
    assert.equal(ctx.timeText(t, KOLKATA, '24h', false, 'AM', 'PM'), '01:30');
    assert.equal(ctx.timeText(t, KOLKATA, '12h', true, 'AM', 'PM'), '1:30 AM');
    assert.equal(ctx.timeText(t, NEW_YORK_STD, 'locale', true, 'AM', 'PM'), '15:00');
    assert.equal(ctx.timeText(t, NEW_YORK_STD, 'locale', false, 'am', 'pm'), '3:00 pm');
    assert.equal(ctx.timeText(at('2026-11-17T12:05:00Z'), 0, '12h', true, 'AM', 'PM'), '12:05 PM');
    assert.equal(ctx.timeText(at('2026-11-17T00:05:00Z'), 0, '12h', true, 'AM', 'PM'), '12:05 AM');
});

test('which locale formats are 24-hour', () => {
    assert.equal(ctx.is24Hour('HH:mm'), true);
    assert.equal(ctx.is24Hour('h:mm AP'), false);
    assert.equal(ctx.is24Hour('h:mm a'), false);
    assert.equal(ctx.is24Hour("HH 'a' mm"), true);
});

test('date label is in the city\'s own day', () => {
    assert.equal(ctx.dateText(at('2026-11-17T20:00:00Z'), NEW_YORK_STD, days, months), 'Tue 17 Nov');
    assert.equal(ctx.dateText(at('2026-11-17T20:00:00Z'), KOLKATA, days, months), 'Wed 18 Nov');
});

test('city name from a zone id', () => {
    assert.equal(ctx.cityName('Europe/Berlin'), 'Berlin');
    assert.equal(ctx.cityName('America/Argentina/Buenos_Aires'), 'Buenos Aires');
    assert.equal(ctx.cityName('UTC'), 'UTC');
});

test('Today, Tomorrow and Yesterday across midnight', () => {
    const t = at('2026-11-17T20:00:00Z'); // local (Kolkata) 01:30 on the 18th
    assert.equal(ctx.dayRelation(t, NEW_YORK_STD, KOLKATA), -1);
    assert.equal(ctx.dayRelation(t, TOKYO, KOLKATA), 0);
    assert.equal(ctx.dayRelation(t, KOLKATA, NEW_YORK_STD), 1);
    assert.equal(ctx.dayRelation(t, KOLKATA, KOLKATA), 0);
    // one minute either side of local midnight
    assert.equal(ctx.dayRelation(at('2026-11-17T18:29:00Z'), TOKYO, KOLKATA), 1);
    assert.equal(ctx.dayRelation(at('2026-11-17T18:31:00Z'), TOKYO, KOLKATA), 0);
});

test('relative offset text, with half hours and the true minus', () => {
    assert.equal(ctx.offsetText(NEW_YORK_STD, KOLKATA), '−10:30');
    assert.equal(ctx.offsetText(TOKYO, KOLKATA), '+3:30');
    assert.equal(ctx.offsetText(KOLKATA, KOLKATA), '+0:00');
    assert.equal(ctx.offsetText(39600, KOLKATA), '+5:30');
    assert.equal(ctx.offsetText(0, 45900), '−12:45');
});

test('DST moves the offset, not the maths: the same city shifts by an hour across the change', () => {
    assert.equal(ctx.offsetText(NEW_YORK_STD, BERLIN_STD), '−6:00');
    assert.equal(ctx.offsetText(NEW_YORK_DST, BERLIN_DST), '−6:00');
    // between the two changes Berlin has moved but New York has not (late March): the gap is five hours
    assert.equal(ctx.offsetText(NEW_YORK_DST, BERLIN_STD), '−5:00');
    // the same instant reads one hour later on the wall after the clocks go forward
    const t = at('2026-03-29T01:30:00Z');
    assert.equal(ctx.timeText(t, BERLIN_STD, '24h', true, '', ''), '02:30');
    assert.equal(ctx.timeText(t, BERLIN_DST, '24h', true, '', ''), '03:30');
});
