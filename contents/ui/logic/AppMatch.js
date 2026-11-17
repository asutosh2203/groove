.pragma library

// Finds the task (window) that belongs to a desktop id. `tasks` is a list of plain
// { appId, launcherUrl, isWindow } records read from Plasma's TasksModel; returns the index or -1.
// A wanted id may arrive with a ".desktop" suffix (firefox.desktop) or really end in it (org.telegram.desktop,
// whose file is org.telegram.desktop.desktop), so both the id and the suffix-stripped id are accepted.
// A task's own ids are its app id and its launcher file name minus the file suffix; matching is exact.
function clean(id) {
    return String(id === null || id === undefined ? "" : id).trim().toLowerCase();
}

function stripSuffix(id) {
    return id.endsWith(".desktop") ? id.slice(0, -".desktop".length) : id;
}

function findTask(entry, tasks) {
    const id = clean(entry);
    if (id.length === 0)
        return -1;
    const wanted = [id, stripSuffix(id)];
    const list = tasks || [];
    for (let i = 0; i < list.length; ++i) {
        const task = list[i] || {};
        if (task.isWindow === false)
            continue;
        const url = String(task.launcherUrl || "");
        const have = [clean(task.appId), stripSuffix(clean(url.substring(url.lastIndexOf("/") + 1)))];
        for (const candidate of have) {
            if (candidate.length > 0 && wanted.indexOf(candidate) >= 0)
                return i;
        }
    }
    return -1;
}

// Like findTask, then a looser second pass for raising a media player: a player's MPRIS DesktopEntry ("spotify") can be
// the first part of its task's id ("spotify-launcher"). Exact matches always win; the loose pass accepts an id that starts
// with the wanted one followed by "-" or ".", and only when exactly one task matches (two matches could raise the wrong app).
function findTaskLoose(entry, tasks) {
    const exact = findTask(entry, tasks);
    if (exact >= 0)
        return exact;
    const id = stripSuffix(clean(entry));
    if (id.length === 0)
        return -1;
    const list = tasks || [];
    let found = -1;
    for (let i = 0; i < list.length; ++i) {
        const task = list[i] || {};
        if (task.isWindow === false)
            continue;
        const url = String(task.launcherUrl || "");
        const have = [clean(task.appId), stripSuffix(clean(url.substring(url.lastIndexOf("/") + 1)))];
        if (!have.some(candidate => candidate.startsWith(id + "-") || candidate.startsWith(id + ".")))
            continue;
        if (found >= 0)
            return -1;
        found = i;
    }
    return found;
}
