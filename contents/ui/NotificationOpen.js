.pragma library

// Decides what a click on a notification does (D-31). First match wins:
// live default action, then the first URL, then the app's desktop entry (when it can be launched), else nothing.
// Plasma clears the actions of an expired notification, so `expired` alone rules out "action".
function resolve(n) {
    const note = n || {};
    if (note.hasDefaultAction === true && note.expired !== true)
        return { kind: "action", target: "" };

    const urls = Array.isArray(note.urls) ? note.urls : (note.urls && note.urls.length !== undefined ? Array.from(note.urls) : []);
    for (const url of urls) {
        const text = String(url === null || url === undefined ? "" : url).trim();
        if (text.length > 0)
            return { kind: "url", target: text };
    }

    // Kept as given: a desktop id can itself end in ".desktop" (org.telegram.desktop), so the launcher tries both forms.
    const entry = String(note.desktopEntry === null || note.desktopEntry === undefined ? "" : note.desktopEntry).trim();
    // A NoDisplay entry (KDE Connect's background daemon) can't be opened, so it is not a target.
    if (entry.length > 0 && note.desktopEntryLaunchable !== false)
        return { kind: "app", target: entry };

    return { kind: "none", target: "" };
}
