const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// ControlLayout.js imports ModuleRegistry.js and Utils.js; here they are loaded into their own contexts and handed in.
const read = (f) => fs.readFileSync(path.join(__dirname, '../contents/ui/logic', f), 'utf8').replace(/^\.pragma library\s*/m, '').replace(/^\.import.*$/gm, '');
const module_ = (file, names) => {
    const ctx = vm.createContext({ Object, Math, JSON, Array, isFinite, Number });
    vm.runInContext(read(file), ctx);
    return Object.fromEntries(names.map((n) => [n, ctx[n]]));
};
const Utils = module_('Utils.js', ['finiteNumber', 'clampNumber']);
const ModuleRegistry = module_('ModuleRegistry.js', ['allModules', 'info', 'defaultLayout', 'minSize', 'maxSize', 'defaultSize']);
const ctx = vm.createContext({ Utils, ModuleRegistry, console: { warn() {} }, JSON, Math, Object, Array, isFinite, Number });
vm.runInContext(read('ControlLayout.js'), ctx);
const j = (v) => JSON.parse(JSON.stringify(v));
const L = ctx;

test('clampedModule keeps a size inside what the module allows', () => {
    assert.deepEqual(j(L.clampedModule('volume', 3, 99)), { w: 3, h: 6 });
    assert.deepEqual(j(L.clampedModule('notifications', 1, 1)), { w: 2, h: 2 }); // minW/minH of 2
    assert.deepEqual(j(L.clampedModule('userPower', 8, 9)), { w: 8, h: 3 }); // maxH of 3
    assert.deepEqual(j(L.clampedModule('wifi', 'x', NaN)), { w: 1, h: 1 });
});

test('sanitize drops unknown and duplicate modules and keeps positions on the grid', () => {
    const out = j(L.sanitize([
        { id: 'media', w: 6, h: 3, v: 2, col: 3, row: 1 },
        { id: 'media', w: 2, h: 2, v: 2 },
        { id: 'nope', w: 1, h: 1, v: 2 },
        null,
    ]));
    assert.equal(out.length, 1);
    assert.deepEqual(out[0], { id: 'media', w: 6, h: 3, v: 2, col: 2, row: 1 }); // col pulled in so w + col <= 8
});

test('sanitize migrates a first-format item (no v) by doubling its size', () => {
    const out = j(L.sanitize([{ id: 'wifi', w: 1, h: 1 }]));
    assert.deepEqual(out, [{ id: 'wifi', w: 2, h: 2, v: 2 }]); // no col/row: it is placed automatically
});

test('sanitize falls back to the default layout when nothing valid is left', () => {
    assert.deepEqual(j(L.sanitize([])), j(ModuleRegistry.defaultLayout()));
    assert.deepEqual(j(L.sanitize([{ id: 'nope' }])), j(ModuleRegistry.defaultLayout()));
});

test('sameLayout compares what would be saved, not the raw arrays', () => {
    assert.equal(L.sameLayout([{ id: 'media', w: 6, h: 3, v: 2 }], [{ id: 'media', w: 6, h: 3, v: 2, extra: 1 }]), true);
    assert.equal(L.sameLayout([{ id: 'media', w: 6, h: 3, v: 2 }], [{ id: 'media', w: 5, h: 3, v: 2 }]), false);
    assert.equal(L.sameLayout(null, undefined), true); // both become the default layout
});

test('committed reads the stored JSON and falls back to the default', () => {
    const stored = JSON.stringify([{ id: 'media', w: 3, h: 3, v: 2, col: 1, row: 1 }]);
    assert.deepEqual(j(L.committed(stored)), [{ id: 'media', w: 3, h: 3, v: 2, col: 1, row: 1 }]);
    for (const bad of ['', 'not json', '[]', '{"a":1}', undefined])
        assert.deepEqual(j(L.committed(bad)), j(ModuleRegistry.defaultLayout()), String(bad));
});

test('removeModule returns a new list, or null for a bad index', () => {
    const layout = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    assert.deepEqual(j(L.removeModule(layout, 1)), [{ id: 'a' }, { id: 'c' }]);
    assert.equal(layout.length, 3); // the input is untouched
    assert.equal(L.removeModule(layout, -1), null);
    assert.equal(L.removeModule(layout, 3), null);
});

test('insertModule inserts at a valid target, appends otherwise, and refuses duplicates', () => {
    const layout = [{ id: 'volume' }, { id: 'media' }];
    assert.deepEqual(j(L.insertModule(layout, 'wifi', 1)).map((m) => m.id), ['volume', 'wifi', 'media']);
    assert.deepEqual(j(L.insertModule(layout, 'wifi', -1)).map((m) => m.id), ['volume', 'media', 'wifi']);
    assert.deepEqual(j(L.insertModule(layout, 'wifi', 99)).map((m) => m.id), ['volume', 'media', 'wifi']);
    assert.equal(L.insertModule(layout, 'media', 0), null);
    assert.equal(layout.length, 2);
    assert.deepEqual(j(L.insertModule([], 'wifi', 0)), [{ id: 'wifi', w: 2, h: 2, v: 2 }]);
});
