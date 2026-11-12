const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.join(__dirname, '../scripts/check-qml.sh');

// Builds a tiny tree plus a stub "qmllint" that prints canned output and exits with a canned code.
function run({ baseline = '3', output = '', exitCode = 0, files = { 'contents/ui/A.qml': '', 'contents/ui/weather/B.js': '' } }) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'checkqml-'));
    for (const [rel, body] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
        fs.writeFileSync(path.join(dir, rel), body);
    }
    fs.mkdirSync(path.join(dir, '.github'), { recursive: true });
    fs.writeFileSync(path.join(dir, '.github/qmllint-baseline.txt'), baseline + '\n');
    const stub = path.join(dir, 'fake-qmllint');
    fs.writeFileSync(stub, `#!/bin/sh\n[ "$1" = "--version" ] && { echo "qmllint stub"; exit 0; }\ncat <<'OUT'\n${output}\nOUT\nexit ${exitCode}\n`, { mode: 0o755 });
    const r = spawnSync('bash', [script], {
        env: { ...process.env, QML_ROOT: dir, QMLLINT: stub, QMLLINT_LOG: path.join(dir, 'lint.log') },
        encoding: 'utf8',
    });
    fs.rmSync(dir, { recursive: true, force: true });
    return { code: r.status, out: r.stdout + r.stderr };
}

const warn = (n) => Array.from({ length: n }, (_, i) => `Warning: contents/ui/A.qml:${i + 1}:1: Unqualified access [unqualified]`).join('\n');

test('at the baseline passes and reports the counts, including weather files', () => {
    const r = run({ baseline: '3', output: warn(3) });
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /files: 2 \(1 QML, 1 JS; 1 under weather\/\)/);
    assert.match(r.out, /warnings: 3 \(baseline 3\)/);
});

test('a warning above the baseline fails', () => {
    const r = run({ baseline: '3', output: warn(4) });
    assert.equal(r.code, 1);
    assert.match(r.out, /warnings went up: 4 > baseline 3/);
});

test('a warning below the baseline passes and says to lower it', () => {
    const r = run({ baseline: '3', output: warn(1) });
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /lower \.github\/qmllint-baseline\.txt to 1/);
});

test('an error or a non-zero qmllint exit fails even with no warnings', () => {
    const r = run({ baseline: '0', output: 'Error: contents/ui/A.qml:2:1: Expected token `;` [syntax]', exitCode: 255 });
    assert.equal(r.code, 1);
    assert.match(r.out, /reported errors \(exit code [1-9][0-9]*\)/);
});

test('an [import] warning is fatal even when under the baseline', () => {
    const r = run({ baseline: '5', output: 'Warning: contents/ui/A.qml:1:1: Failed to import org.kde.kirigami [import]' });
    assert.equal(r.code, 1);
    assert.match(r.out, /\[import\] warning/);
});

test('a bad baseline file or an empty tree is a setup error, not a pass', () => {
    assert.equal(run({ baseline: 'abc', output: '' }).code, 2);
    assert.equal(run({ baseline: '0', output: '', files: {} }).code, 2);
});
