const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.join(__dirname, '../scripts/check-qml.sh');
const A = 'contents/ui/A.qml';
const B = 'contents/ui/B.qml';

// Builds a tiny tree plus a stub "qmllint". The stub prints `counts[file]` warnings for each file it is given, and
// one more for a probe copy (`__probe<place><style>_<name>`) unless the file is listed in `blind` (analysis "aborted").
function run({ baseline = { [A]: 3 }, counts = { [A]: 3 }, files = [A, 'contents/ui/weather/W.js'], blind = [], exempt = [], extra = '', exitCode = 0, args = [] }) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'checkqml-'));
    for (const rel of files) {
        fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
        fs.writeFileSync(path.join(dir, rel), rel.endsWith('.qml') ? 'import QtQuick\nItem {\n}\n' : '');
    }
    fs.mkdirSync(path.join(dir, '.github'), { recursive: true });
    const text = (m) => Object.entries(m).map(([f, n]) => `${n} ${f}`).join('\n') + '\n';
    fs.writeFileSync(path.join(dir, '.github/qmllint-baseline.txt'), text(baseline));
    if (exempt.length) fs.writeFileSync(path.join(dir, '.github/qmllint-probe-exempt.txt'), exempt.join('\n') + '\n');
    const cases = Object.entries(counts).map(([f, n]) => {
        const name = path.basename(f);
        const probe = blind.includes(f) ? n : n + 1;
        return `  *__probe*_${name}) emit "$a" ${probe} ;;\n  *${name}) emit "$a" ${n} ;;`;
    }).join('\n');
    const stub = path.join(dir, 'fake-qmllint');
    fs.writeFileSync(stub, `#!/bin/sh
[ "$1" = "--version" ] && { echo "qmllint stub"; exit 0; }
emit() { i=1; while [ "$i" -le "$2" ]; do echo "Warning: $1:$i:1: Unqualified access [unqualified]"; i=$((i+1)); done; }
for a in "$@"; do
case "$a" in
${cases}
esac
done
cat <<'OUT'
${extra}
OUT
exit ${exitCode}
`, { mode: 0o755 });
    const r = spawnSync('bash', [script, ...args], {
        env: { ...process.env, QML_ROOT: dir, QMLLINT: stub, QMLLINT_LOG: path.join(dir, 'lint.log') },
        encoding: 'utf8',
    });
    const written = fs.readFileSync(path.join(dir, '.github/qmllint-baseline.txt'), 'utf8');
    fs.rmSync(dir, { recursive: true, force: true });
    return { code: r.status, out: r.stdout + r.stderr, written };
}

test('at the baseline passes and reports the counts and the probe, including weather files', () => {
    const r = run({});
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /files: 2 \(1 QML, 1 JS; 1 under weather\/\)/);
    assert.match(r.out, /warnings: 3 \(baseline 3\)/);
    assert.match(r.out, /probe: 1 QML files probed at 3 places, 0 failed, 0 exempt/);
});

test('one file going up fails even when another file dropped by the same amount', () => {
    const r = run({ files: [A, B], baseline: { [A]: 3, [B]: 3 }, counts: { [A]: 4, [B]: 2 } });
    assert.equal(r.code, 1);
    assert.match(r.out, /contents\/ui\/A\.qml::warnings went up: 4 > baseline 3/);
});

test('a new file with warnings fails: its baseline is 0', () => {
    const r = run({ files: [A, B], baseline: { [A]: 3 }, counts: { [A]: 3, [B]: 1 } });
    assert.equal(r.code, 1);
    assert.match(r.out, /contents\/ui\/B\.qml::warnings went up: 1 > baseline 0/);
});

test('a small drop passes and says to lower it', () => {
    const r = run({ baseline: { [A]: 4 }, counts: { [A]: 3 } });
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /warnings dropped 4 -> 3: lower the baseline/);
    assert.doesNotMatch(r.out, /verify the analysis didn't abort/);
});

test('a drop of more than half is called out loudly', () => {
    const r = run({ baseline: { [A]: 10 }, counts: { [A]: 4 } });
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /fell from 10 to 4 \(more than half\): verify the analysis didn't abort/);
});

test('a file whose analysis silently aborted fails the probe', () => {
    const r = run({ baseline: { [A]: 10 }, counts: { [A]: 4 }, blind: [A] });
    assert.equal(r.code, 1);
    assert.match(r.out, /contents\/ui\/A\.qml::probe failed/);
    assert.match(r.out, /3 failed/); // top, mid and end
});

test('a file that cannot be probed passes only when it is listed as exempt', () => {
    const bad = run({ blind: [A] });
    assert.equal(bad.code, 1);
    const ok = run({ blind: [A], exempt: [A] });
    assert.equal(ok.code, 0, ok.out);
    assert.match(ok.out, /0 failed, 3 exempt/);
});

test('an exempt file that probes fine is flagged for removal from the list', () => {
    const r = run({ exempt: [A] });
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /now works here: remove it from/);
});

test('an error or a non-zero qmllint exit fails even with no warnings', () => {
    const r = run({ baseline: {}, counts: {}, extra: 'Error: contents/ui/A.qml:2:1: Expected token `;` [syntax]', exitCode: 255 });
    assert.equal(r.code, 1);
    assert.match(r.out, /reported errors \(exit code [1-9][0-9]*\)/);
});

test('an [import] warning is fatal even when under the baseline', () => {
    const r = run({ extra: 'Warning: contents/ui/A.qml:1:1: Failed to import org.kde.kirigami [import]' });
    assert.equal(r.code, 1);
    assert.match(r.out, /\[import\] warning/);
});

test('--lower-baseline writes only lower numbers and drops files that reached zero', () => {
    const r = run({ files: [A, B], baseline: { [A]: 5, [B]: 2 }, counts: { [A]: 3, [B]: 0 }, args: ['--lower-baseline'] });
    assert.equal(r.code, 0, r.out);
    assert.equal(r.written.trim(), `3 ${A}`);
});

test('--lower-baseline refuses while the check fails and leaves the baseline alone', () => {
    const r = run({ files: [A, B], baseline: { [A]: 3, [B]: 3 }, counts: { [A]: 4, [B]: 1 }, args: ['--lower-baseline'] });
    assert.equal(r.code, 1);
    assert.match(r.out, /not lowering the baseline while the check fails/);
    assert.equal(r.written, `3 ${A}\n3 ${B}\n`);
});

test('a blind spot can be exempted for one place only', () => {
    // The stub is blind at every place, so exempting just "top" leaves mid and end failing.
    const r = run({ blind: [A], exempt: [`${A}:top`] });
    assert.equal(r.code, 1);
    assert.match(r.out, /failed at the mid of the file/);
    assert.match(r.out, /failed at the end of the file/);
    assert.doesNotMatch(r.out, /failed at the top of the file/);
    const ok = run({ blind: [A], exempt: [`${A}:top`, `${A}:mid`, `${A}:end`] });
    assert.equal(ok.code, 0, ok.out);
});
