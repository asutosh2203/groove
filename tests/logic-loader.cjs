// Loads a logic module with its `.import "X.js" as Name` lines resolved to the other modules, the way QML does.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dir = path.join(__dirname, '../contents/ui/logic');
const cache = {};

function load(file) {
    if (cache[file]) return cache[file];
    const src = fs.readFileSync(path.join(dir, file), 'utf8');
    const globals = {};
    for (const m of src.matchAll(/^\.import "(\w+\.js)" as (\w+)/gm)) globals[m[2]] = load(m[1]);
    const ctx = vm.createContext(globals);
    vm.runInContext(src.replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, ''), ctx);
    return (cache[file] = ctx);
}

module.exports = { load, j: (v) => JSON.parse(JSON.stringify(v)) };
