#!/usr/bin/env node
// Token ratchet: counts hardcoded layout and motion literals (radius, font size, icon size, spacing, padding, margins,
// opacity other than 0 and 1, animation duration, timer interval, easing) per file under contents/ui, and fails when a
// file has more than its entry in .github/token-baseline.txt (a file with no entry has a baseline of 0, so new files
// must use the tokens in controlcenter/Tokens.js). Tokens.js itself is where the values live and is not counted.
//
//   node scripts/check-tokens.cjs                   check against the baseline
//   node scripts/check-tokens.cjs --lower-baseline  write lower counts only; refuses to raise any
//   node scripts/check-tokens.cjs --write-baseline  write the current counts (first creation only)
//
// Only bare numeric literals are seen: a value computed from other values (`width * 0.22`) or read from a token is not
// counted, so the numbers are a floor. docs/TOKEN-AUDIT.md explains the categories.
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const NUM = '(-?\\d+(?:\\.\\d+)?)';
const RULES = [
    { kind: 'radius', re: new RegExp('^\\s*(?:\\w+\\.)?radius:\\s*' + NUM + '\\s*$') },
    { kind: 'font', re: new RegExp('font\\.pixelSize:\\s*' + NUM + '\\s*$') },
    { kind: 'spacing', re: new RegExp('^\\s*spacing:\\s*' + NUM + '\\s*$'), skipZero: true },
    { kind: 'spacing', re: new RegExp('^\\s*(?:padding|\\w*Padding):\\s*' + NUM + '\\s*$'), skipZero: true },
    { kind: 'margin', re: new RegExp('^\\s*(?:\\w+\\.)?(?:margins|\\w*Margin):\\s*' + NUM + '\\s*$'), skipZero: true },
    { kind: 'opacity', re: new RegExp('^\\s*opacity:\\s*' + NUM + '\\s*$'), skipValues: ['0', '1'] },
    { kind: 'icon', re: new RegExp('^\\s*(?:glyphSize|iconSize|iconHeight):\\s*' + NUM) }
];
// Motion literals can share a line (`NumberAnimation { duration: 105; easing.type: Easing.OutCubic }`), so each counts.
const MOTION = [new RegExp('\\bduration:\\s*' + NUM, 'g'), new RegExp('\\binterval:\\s*' + NUM, 'g'), /\beasing\.type:\s*Easing\.\w+/g];
const ICON_ITEM = /^\s*(Kirigami\.Icon|\w*Glyph|\w*Icon)\s*\{/;
const ICON_SIZE = new RegExp('^\\s*(?:Layout\\.preferred)?(?:[wW]idth|[hH]eight):\\s*' + NUM + '\\s*$');

// Counts per kind for one file's text.
function count(text) {
    const result = { radius: 0, font: 0, icon: 0, spacing: 0, margin: 0, opacity: 0, motion: 0 };
    const stack = [];
    for (const line of text.split('\n')) {
        const trimmed = line.trim();
        const opens = (line.match(/\{/g) || []).length;
        const closes = (line.match(/\}/g) || []).length;
        const startsIcon = ICON_ITEM.test(line) && opens > closes;
        if (startsIcon)
            stack.push('icon');
        else if (opens > closes)
            for (let i = 0; i < opens - closes; i++) stack.push('x');
        else if (closes > opens)
            for (let i = 0; i < closes - opens; i++) stack.pop();
        if (trimmed.startsWith('//'))
            continue;
        for (const re of MOTION) {
            re.lastIndex = 0;
            result.motion += (line.match(re) || []).length;
        }
        for (const rule of RULES) {
            const m = rule.re.exec(line);
            if (!m)
                continue;
            if (rule.skipZero && Number(m[1]) === 0)
                break;
            if (rule.skipValues && rule.skipValues.includes(m[1]))
                break;
            result[rule.kind]++;
            break;
        }
        if (stack[stack.length - 1] === 'icon' || startsIcon) {
            if (ICON_SIZE.test(line))
                result.icon++;
        }
    }
    return result;
}

function total(counts) {
    return Object.values(counts).reduce((a, b) => a + b, 0);
}

function files(root) {
    const out = [];
    const walk = (dir) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const p = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                if (entry.name !== 'icons') walk(p);
            } else if (/\.(qml|js)$/.test(entry.name) && p !== path.join(root, 'contents/ui/controlcenter/Tokens.js')) {
                out.push(p);
            }
        }
    };
    walk(path.join(root, 'contents/ui'));
    return out.sort();
}

// { "contents/ui/x.qml": n } for every file with at least one literal.
function countAll(root) {
    const result = {};
    for (const f of files(root)) {
        const n = total(count(fs.readFileSync(f, 'utf8')));
        if (n > 0)
            result[path.relative(root, f)] = n;
    }
    return result;
}

function readBaseline(file) {
    const result = {};
    if (!fs.existsSync(file))
        return result;
    for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
        const m = /^(\d+) (.+)$/.exec(line.trim());
        if (m)
            result[m[2]] = Number(m[1]);
    }
    return result;
}

function formatBaseline(counts) {
    return Object.keys(counts).sort().map((f) => counts[f] + ' ' + f).join('\n') + '\n';
}

// Files whose count is above their baseline: [{ file, count, baseline }].
function over(counts, baseline) {
    return Object.keys(counts).filter((f) => counts[f] > (baseline[f] || 0)).map((f) => ({ file: f, count: counts[f], baseline: baseline[f] || 0 }));
}

module.exports = { count, total, countAll, readBaseline, formatBaseline, over };

if (require.main === module) {
    const root = path.join(__dirname, '..');
    const baselineFile = path.join(root, '.github/token-baseline.txt');
    const mode = process.argv[2] || '';
    const counts = countAll(root);
    const baseline = readBaseline(baselineFile);
    if (mode === '--write-baseline') {
        fs.writeFileSync(baselineFile, formatBaseline(counts));
        console.log('baseline written: ' + total(counts) + ' literals in ' + Object.keys(counts).length + ' files');
        process.exit(0);
    }
    const bad = over(counts, baseline);
    if (bad.length > 0) {
        for (const b of bad)
            console.error('::error file=' + b.file + '::' + b.count + ' hardcoded layout or motion literals, baseline ' + b.baseline + ': use the tokens in controlcenter/Tokens.js');
        process.exit(1);
    }
    if (mode === '--lower-baseline') {
        const lowered = {};
        for (const f of Object.keys(counts))
            lowered[f] = counts[f];
        fs.writeFileSync(baselineFile, formatBaseline(lowered));
        console.log('baseline lowered to ' + total(lowered) + ' literals in ' + Object.keys(lowered).length + ' files');
        process.exit(0);
    }
    const lower = Object.keys(baseline).filter((f) => (counts[f] || 0) < baseline[f]);
    for (const f of lower)
        console.log('::notice file=' + f + '::dropped ' + baseline[f] + ' -> ' + (counts[f] || 0) + ': lower the baseline (node scripts/check-tokens.cjs --lower-baseline)');
    console.log('ok: ' + total(counts) + ' literals in ' + Object.keys(counts).length + ' files (baseline ' + Object.values(baseline).reduce((a, b) => a + b, 0) + ')');
}
