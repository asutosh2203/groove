// The real widget manifests, as the registry takes them: [{ id, manifest }].
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '../contents/ui/widgets');
module.exports = fs.readdirSync(root, { withFileTypes: true }).filter(d => d.isDirectory()).map(d => ({ id: d.name, manifest: JSON.parse(fs.readFileSync(path.join(root, d.name, 'manifest.json'), 'utf8')) }));
