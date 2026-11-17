const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const widgets = path.join(__dirname, '../contents/ui/widgets');

test('every manifest has a view file for each span it declares', () => {
    for (const id of fs.readdirSync(widgets, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name)) {
        const manifest = JSON.parse(fs.readFileSync(path.join(widgets, id, 'manifest.json'), 'utf8'));
        for (const span of manifest.spans)
            assert.ok(fs.existsSync(path.join(widgets, id, 'View' + span + '.qml')), id + ' has no View' + span + '.qml');
    }
});
