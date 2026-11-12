.pragma library
.import "ModuleRegistry.js" as ModuleRegistry
.import "Utils.js" as Utils

// Control Center layout rules as pure functions: sizes clamp to what each module allows, a saved layout is cleaned
// (unknown or duplicate modules dropped, positions kept on the 8-column grid), and modules are added or removed
// without mutating the caller's array. The grid is 8 units wide; saved items carry v: 2 (the unit size after the
// 2x migration of the first layout format).

const columns = 8;
const maxRows = 64;

function clampedModule(id, widthUnits, heightUnits) {
    const minSize = ModuleRegistry.minSize(id);
    const maxSize = ModuleRegistry.maxSize(id);
    return {
        "w": Math.round(Utils.clampNumber(widthUnits, minSize.w, maxSize.w)),
        "h": Math.round(Utils.clampNumber(heightUnits, minSize.h, maxSize.h))
    };
}

function sanitize(layout) {
    const known = {};
    const modules = ModuleRegistry.allModules();
    for (let i = 0; i < modules.length; ++i)
        known[modules[i].id] = true;

    const out = [];
    const seen = {};
    for (let j = 0; j < layout.length; ++j) {
        const item = layout[j] || {};
        if (!known[item.id] || seen[item.id])
            continue;

        const migrated = item.v === 2;
        const size = clampedModule(item.id, Utils.finiteNumber(item.w, 1) * (migrated ? 1 : 2), Utils.finiteNumber(item.h, 1) * (migrated ? 1 : 2));
        const col = isFinite(Number(item.col)) ? Math.round(Utils.clampNumber(item.col, 0, 7)) : -1;
        const row = isFinite(Number(item.row)) ? Math.max(0, Math.round(Utils.finiteNumber(item.row, 0))) : -1;
        const saved = {
            "id": item.id,
            "w": size.w,
            "h": size.h,
            "v": 2
        };
        if (col >= 0 && row >= 0) {
            saved.col = Math.min(columns - size.w, col);
            saved.row = Math.min(maxRows - size.h, row);
        }
        seen[item.id] = true;
        out.push(saved);
    }
    return out.length > 0 ? out : ModuleRegistry.defaultLayout();
}

function sameLayout(left, right) {
    return JSON.stringify(sanitize(left || [])) === JSON.stringify(sanitize(right || []));
}

// The layout stored in the widget config (a JSON string), or the default when it is empty or unreadable.
function committed(raw) {
    if (raw && raw.length > 0) {
        try {
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed) && parsed.length > 0)
                return sanitize(parsed);

        } catch (e) {
            console.warn("Dynamic Island: invalid control center layout JSON", e);
        }
    }
    return ModuleRegistry.defaultLayout();
}

// null when there is nothing to remove.
function removeModule(layout, index) {
    if (index < 0 || index >= layout.length)
        return null;

    const out = layout.slice();
    out.splice(index, 1);
    return out;
}

// null when the module is already in the layout. A target inside the list inserts there, anything else appends.
function insertModule(layout, id, target) {
    for (let i = 0; i < layout.length; ++i) {
        if (layout[i].id === id)
            return null;

    }
    const item = ModuleRegistry.defaultSize(id);
    const out = layout.slice();
    if (target >= 0 && target <= out.length)
        out.splice(target, 0, item);
    else
        out.push(item);

    return out;
}
