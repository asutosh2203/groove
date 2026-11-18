pragma ComponentBehavior: Bound

import QtQuick
import "../logic/ArtCache.js" as ArtCache

// Cover art for the shown player, fetched with curl once per new remote URL (ArtCache.js says why) and shown from disk.
// Nothing runs while the URL stays the same; with no runner, or for a local URL, the URL passes through unchanged.
Item {
    id: cache

    // The CommandRunner of this island (the only command engine, D-37); null passes every URL through.
    property var runner: null
    // The player's own cover URL.
    property string url: ""
    // url -> { path } or { failed }, bounded by ArtCache.remember; `revision` re-reads it.
    property var results: ({})
    property int revision: 0
    // What the artwork items load.
    readonly property string source: {
        if (revision < 0) // never true: reading it re-evaluates this when a fetch finishes
            return "";
        return cache.runner ? ArtCache.sourceFor(cache.url, cache.results) : cache.url;
    }

    function fetch(url) {
        if (!cache.runner || !ArtCache.isFetchable(url) || cache.results[url])
            return;
        cache.runner.run(ArtCache.command(url), stdout => cache.finished(url, stdout));
    }

    function finished(url, stdout) {
        const path = ArtCache.pathFrom(stdout);
        ArtCache.remember(cache.results, url, path ? { "path": path } : { "failed": true });
        cache.revision++;
    }

    onUrlChanged: fetch(url)
    onRunnerChanged: fetch(url)
    Component.onCompleted: fetch(url)
}
