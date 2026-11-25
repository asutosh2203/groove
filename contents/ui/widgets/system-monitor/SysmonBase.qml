pragma ComponentBehavior: Bound

import QtQuick
import ".." as Widgets
import "../../controlcenter/Tokens.js" as T
import "../../logic/Sysmon.js" as Sysmon

// What every System Monitor span shares (D-65): the stats the span shows, the view hold that makes the hub sample once a
// second, and the click that opens Plasma's System Monitor.
Widgets.WidgetView {
    id: view

    readonly property var hub: view.services.sysmon ?? null
    readonly property var s: view.strings
    readonly property var kinds: Sysmon.slotKinds(view.settings, view.span)
    readonly property bool tall: view.boxHeight >= T.widgetTallRoom
    // A stat that cannot read says so in its own cell; the widget is loading only while none has a first sample.
    readonly property bool anyAnswered: view.hub !== null && view.kinds.some(k => view.hub.face(k).state !== "loading")

    widgetState: view.anyAnswered ? "ready" : "loading"
    clickAction: ({ "type": "app", "value": "org.kde.plasma-systemmonitor" })

    // The host injects `services` after the view loads, so the hold is taken when the hub arrives.
    property var heldHub: null

    function hold() {
        if (view.hub === view.heldHub)
            return ;
        view.drop();
        view.heldHub = view.hub;
        if (view.heldHub)
            view.heldHub.holdView();
    }

    function drop() {
        if (view.heldHub)
            view.heldHub.releaseView();
        view.heldHub = null;
    }

    onHubChanged: view.hold()
    Component.onCompleted: view.hold()
    Component.onDestruction: view.drop()
}
