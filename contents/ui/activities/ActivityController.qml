pragma ComponentBehavior: Bound

import QtQuick
import "../logic/ActivityResolver.js" as Resolver

// Holds the island's activity providers and answers "which one, and what does it say". The decisions are pure
// (logic/ActivityResolver.js, D-13 and D-35); this object feeds them the live providers.
QtObject {
    id: controller

    property list<ActivityProvider> providers

    readonly property var currentProvider: Resolver.highest(providers)
    readonly property string currentKey: Resolver.keyOf(currentProvider)

    function providerByKey(key) {
        return Resolver.byKey(providers, key);
    }

    function providerFor(requestedKey) {
        return Resolver.pick(providers, currentProvider, requestedKey);
    }

    function keyFor(requestedKey) {
        return Resolver.keyOf(providerFor(requestedKey));
    }

    function priorityFor(requestedKey) {
        return Resolver.priorityOf(providerFor(requestedKey));
    }

    function visualComponentFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "visualComponent", null);
    }

    function compactComponentFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "compactComponent", null);
    }

    function expandedComponentFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "expandedComponent", null);
    }

    function autoCloseMsFor(requestedKey) {
        return Resolver.autoCloseMs(providerFor(requestedKey));
    }

    // The title, or `fallback` when there is no provider or it has none.
    function titleFor(requestedKey, fallback) {
        const provider = providerFor(requestedKey);
        return provider && provider.title.length > 0 ? provider.title : fallback;
    }

    function subtitleFor(requestedKey, fallback) {
        return Resolver.field(providerFor(requestedKey), "subtitle", fallback);
    }

    function artworkFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "artwork", null);
    }

    function progressVisibleFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "progressVisible", false);
    }

    function progressToFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "progressTo", 1);
    }

    function progressValueFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "progressValue", 0);
    }

    function progressAccentFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "progressAccent", "#5ac8fa");
    }

    function mediaControlsFor(requestedKey) {
        return Resolver.field(providerFor(requestedKey), "mediaControlsVisible", false);
    }
}
