pragma ComponentBehavior: Bound

import QtQuick

// The base of every widget view (contract v1, D-54). The host sets the injected properties after loading the view, and the
// view sizes itself from `boxWidth` x `boxHeight` only. They are plain properties, not `required`, because a Loader cannot
// pass required ones to a view it loads from a URL. The view reports its state and an optional click action back.
Item {
    id: view

    // Injected by the host.
    property string span: "1x1"
    property var settings: ({})
    property var services: ({})
    property var tokens: null
    property var strings: null
    property var locale: Qt.locale()
    property bool use24Hour: true
    property bool reduceMotion: false
    // "updated 2 h ago" while the data is stale, else empty. The view shows it in place of its detail line.
    property string staleText: ""

    // Reported to the host: loading, ready, stale, error or needsSetup, when the data is from, what a click does
    // ({ type: "url", value }, { type: "app", value } or { type: "calendar" }; null is not clickable) and the text for the
    // error and needs-setup placeholders.
    property string widgetState: "ready"
    property double lastUpdated: 0
    property var clickAction: null
    property string message: ""

    readonly property real boxWidth: width
    readonly property real boxHeight: height
}
