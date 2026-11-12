.pragma library

// Is a fullscreen window covering the screen the island is on? `tasks` are plain
// { isWindow, fullScreen, minimized } records read from Plasma's TasksModel (already limited to this
// screen and the current virtual desktop). Decorative animation pauses while one is on top (D-34).
function covering(tasks) {
    for (const t of tasks || []) {
        if (t && t.isWindow !== false && t.fullScreen === true && t.minimized !== true)
            return true;
    }
    return false;
}
