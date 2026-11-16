// D-50: the Job object behind JobDetailsRole must never come out of Model.data(): QML would own it, the garbage
// collector would delete it, and plasmashell would crash on its next read of that job.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..', 'contents');

function qmlFiles(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e =>
        e.isDirectory() ? qmlFiles(path.join(dir, e.name)) : e.name.endsWith('.qml') ? [path.join(dir, e.name)] : []);
}

test('no QML reads JobDetailsRole through data()', () => {
    for (const file of qmlFiles(root)) {
        const lines = fs.readFileSync(file, 'utf8').split('\n');
        lines.forEach((line, i) => {
            assert.ok(!(line.includes('.data(') && line.includes('JobDetailsRole')), `${file}:${i + 1}`);
        });
    }
});

test('NotificationService reads the Job through a model-role delegate', () => {
    const src = fs.readFileSync(path.join(root, 'ui/services/NotificationService.qml'), 'utf8');
    assert.match(src, /Instantiator\s*\{[\s\S]*required property var jobDetails/);
    assert.match(src, /jobDetailsHolder\.objectAt\(row\)/);
});
