pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter/Tokens.js" as T
import "../logic/WidgetRegistry.js" as Registry
import "../logic/WidgetState.js" as WidgetState

// The widget host (D-54): one placement on the tile surface (job-tile style, D-52). It loads the view for the placement's
// span, injects the host properties, holds the declared service subscriptions for as long as the slot exists, draws the
// standard-state placeholders and runs the widget's click action. A widget that no longer exists keeps its slot.
Rectangle {
    id: slot

    required property var app
    required property var placement

    readonly property var manifest: slot.app.widgets.registry.byId[slot.placement.widget] || null
    readonly property bool available: slot.manifest !== null && slot.manifest.spans.indexOf(slot.placement.span) >= 0
    readonly property var settings: slot.manifest ? Registry.resolveSettings(slot.manifest, slot.placement.settings, slot.placement.settingsVersion) : ({})
    readonly property var declared: slot.manifest ? slot.manifest.services : []
    readonly property var zones: slot.manifest && slot.declared.indexOf("clock") >= 0 ? slot.manifest.settings.filter(f => f.type === "timezone").map(f => String(slot.settings[f.key])) : []
    readonly property var weather: slot.declared.indexOf("weather") >= 0 ? slot.app.weatherHub.serviceFor(slot.settings.location) : null
    readonly property var view: loader.item
    readonly property string viewState: slot.view ? slot.view.widgetState : "loading"
    readonly property bool showsContent: slot.available && (slot.viewState === "ready" || slot.viewState === "stale")
    readonly property bool stale: slot.viewState === "stale"
    readonly property var action: slot.showsContent && slot.view ? slot.view.clickAction : null
    readonly property bool clickable: slot.action !== null && slot.action !== undefined

    // What this slot currently holds, so a change releases exactly what it took.
    property var heldClock: null
    property var heldZones: []
    property var heldWeather: null

    function release() {
        if (slot.heldClock)
            slot.heldClock.unsubscribe(slot.heldZones);
        if (slot.heldWeather)
            slot.heldWeather.unsubscribe();
        slot.heldClock = null;
        slot.heldZones = [];
        slot.heldWeather = null;
    }

    // Takes what the slot needs now; a call that changes nothing does nothing, so a binding re-evaluating costs no churn.
    function hold() {
        const wantClock = slot.available && slot.declared.indexOf("clock") >= 0 ? slot.app.clock : null;
        const wantWeather = slot.available ? slot.weather : null;
        const wantZones = wantClock ? slot.zones : [];
        if (wantClock === slot.heldClock && wantWeather === slot.heldWeather && JSON.stringify(wantZones) === JSON.stringify(slot.heldZones))
            return ;
        slot.release();
        slot.heldClock = wantClock;
        slot.heldZones = wantZones;
        slot.heldWeather = wantWeather;
        if (wantClock)
            wantClock.subscribe(wantZones);
        if (wantWeather)
            wantWeather.subscribe();
    }

    onZonesChanged: Qt.callLater(slot.hold)
    onWeatherChanged: Qt.callLater(slot.hold)
    Component.onCompleted: slot.hold()
    Component.onDestruction: slot.release()

    radius: T.radiusInner
    color: slot.clickable && hover.hovered ? T.rowHover : T.row

    Behavior on color {
        enabled: !slot.app.reduceMotion

        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    HoverHandler {
        id: hover

        enabled: slot.clickable
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: slot.clickable
        onClicked: slot.app.runWidgetAction(slot.action)
    }

    Loader {
        id: loader

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: slot.height - (slot.stale ? T.widgetStaleLine : 0)
        active: slot.available
        source: slot.available ? Qt.resolvedUrl("../widgets/" + slot.placement.widget + "/View" + slot.placement.span + ".qml") : ""
        visible: slot.showsContent
    }

    // The injected properties (WidgetView). Bound, so a settings change reaches the view without recreating it.
    Binding {
        target: loader.item
        property: "span"
        value: slot.placement.span
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: loader.item
        property: "settings"
        value: slot.settings
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: loader.item
        property: "services"
        value: ({ "clock": slot.declared.indexOf("clock") >= 0 ? slot.app.clock : null, "weather": slot.weather })
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: loader.item
        property: "strings"
        value: slot.app.strings
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: loader.item
        property: "use24Hour"
        value: slot.app.use24Hour
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: loader.item
        property: "reduceMotion"
        value: slot.app.reduceMotion
        when: loader.item !== null
        restoreMode: Binding.RestoreNone
    }

    // A quiet skeleton while the first data arrives: static, so nothing repaints (principle 9).
    Column {
        id: skeleton

        anchors.fill: parent
        anchors.margins: T.widgetPadding
        spacing: T.gap
        visible: slot.available && slot.viewState === "loading"

        Repeater {
            model: [0.4, 0.7, 0.55]

            delegate: Rectangle {
                id: bar

                required property real modelData

                width: skeleton.width * bar.modelData
                height: T.widgetSkeletonHeight
                radius: T.radiusSmall
                color: T.chip
            }
        }
    }

    PlasmaLabel {
        anchors.fill: parent
        anchors.margins: T.widgetPadding
        visible: !slot.available || slot.viewState === "error" || slot.viewState === "needsSetup"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: T.textSecondary
        font.pixelSize: T.fontBody
        text: !slot.available ? slot.app.strings.widgetUnavailable : slot.view && slot.view.message.length > 0 ? slot.view.message : slot.viewState === "needsSetup" ? slot.app.strings.widgetSetLocation : slot.app.strings.widgetError
    }

    PlasmaLabel {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: T.widgetPadding
        anchors.rightMargin: T.widgetPadding
        height: T.widgetStaleLine
        visible: slot.stale
        color: T.textSecondary
        font.pixelSize: T.fontCaption
        elide: Text.ElideRight
        text: slot.stale && slot.view ? slot.app.strings.updatedAgo(WidgetState.age(slot.view.lastUpdated, Date.now()).unit, WidgetState.age(slot.view.lastUpdated, Date.now()).n) : ""
    }
}
