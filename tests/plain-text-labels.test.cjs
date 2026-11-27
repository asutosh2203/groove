const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// AutoText turns a tag in outside text (a notification title, a track name) into rich text that loads remote images.
// PlasmaLabel is plain by default (tst_PlainLabels.qml); a bare Text or QQC2.Label must say its format whenever its text is
// not a fixed string, so a new label cannot silently fall back to AutoText.
const ui = path.join(__dirname, '../contents/ui');

function qmlFiles(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).reduce((all, e) => {
        const p = path.join(dir, e.name);
        return all.concat(e.isDirectory() ? qmlFiles(p) : e.name.endsWith('.qml') ? [p] : []);
    }, []);
}

const fixed = /^(?:"[^"]*"|i18nc?\("[^"]*"(?:,\s*"[^"]*")?\))$/;

// Bare Text / Label elements: their own `text:` and `textFormat:` lines, nested elements excluded.
function bareLabels(source) {
    const out = [];
    const stack = [];
    source.split('\n').forEach((raw, i) => {
        const line = raw.split('//')[0];
        const open = line.match(/^\s*([A-Z][\w.]*)\s*\{/);
        if (open || line.includes('{'))
            stack.push({ type: open ? open[1] : null, line: i + 1, text: null, format: false });
        const top = stack[stack.length - 1];
        if (top) {
            const t = line.match(/^\s*text:\s*(.*?)\s*$/);
            if (t)
                top.text = t[1];
            if (/^\s*textFormat:/.test(line))
                top.format = true;
        }
        for (let n = (line.match(/\}/g) || []).length; n > 0 && stack.length; --n) {
            const el = stack.pop();
            if (/^(?:Text|Label|QQC2\.Label|PlasmaComponents3?\.Label)$/.test(el.type || '') && el.text !== null)
                out.push(el);
        }
    });
    return out;
}

test('every bare Text or Label that shows changing text declares its textFormat', () => {
    const missing = [];
    for (const file of qmlFiles(ui)) {
        for (const el of bareLabels(fs.readFileSync(file, 'utf8'))) {
            if (!el.format && !fixed.test(el.text))
                missing.push(path.relative(ui, file) + ':' + el.line + ' ' + el.text);
        }
    }
    assert.deepEqual(missing, []);
});

test('the scanner sees a bare label without a format', () => {
    const found = bareLabels('Item {\n    Text {\n        text: app.title\n    }\n    Text {\n        text: "fixed"\n    }\n}\n');
    assert.equal(found.length, 2);
    assert.equal(found[0].format, false);
    assert.equal(fixed.test(found[1].text), true);
});

test('PlasmaLabel itself is plain', () => {
    assert.match(fs.readFileSync(path.join(ui, 'PlasmaLabel.qml'), 'utf8'), /^\s*textFormat:\s*Text\.PlainText\s*$/m);
});
