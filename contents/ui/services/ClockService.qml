pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.clock as PlasmaClock
import "../logic/ClockFormat.js" as ClockFormat
import "../logic/Subscribers.js" as Subs

// Time for the Clock widgets (D-55), one per island. Plasma's Clock (as the stock digital clock uses it) owns time zones and
// DST. Nothing exists while no view subscribes: the Clocks (each holds a minute-aligned timer) are created only while
// subscribed plus a 30 s grace (principle 9), and `nowMs` changes once a minute, never every second.
Item {
    id: service

    // The instant of the last minute tick, the local offset and the offset of every subscribed zone, in seconds.
    property double nowMs: Date.now()
    property real localOffset: 0
    property string localZone: ""
    // What a local-zone clock is called by default: the island's weather city when set (set by main.qml).
    property string localLabel: ""
    property var offsets: ({})
    property var subscribers: Subs.create()
    property var zoneCounts: ({})
    property bool active: false
    // Distinct zones other than local while active; each gets a Clock.
    readonly property var zones: Object.keys(zoneCounts).filter(zone => zone !== "local" && zoneCounts[zone] > 0)

    function syncActive() {
        const next = Subs.isActive(subscribers, Date.now());
        if (next === active)
            return ;
        active = next;
        if (!active)
            zoneCounts = ({});
    }

    // list: the zone ids a view uses ("local" or an IANA id). Calls come in pairs.
    function subscribe(list) {
        const counts = Object.assign({}, zoneCounts);
        for (const zone of list)
            counts[zone] = (counts[zone] || 0) + 1;
        zoneCounts = counts;
        subscribers = Subs.add(subscribers);
        graceTimer.stop();
        syncActive();
        recompute();
    }

    function unsubscribe(list) {
        const counts = Object.assign({}, zoneCounts);
        for (const zone of list)
            counts[zone] = Math.max(0, (counts[zone] || 0) - 1);
        zoneCounts = counts;
        subscribers = Subs.remove(subscribers, Date.now());
        if (subscribers.count === 0) {
            graceTimer.interval = Math.max(1, Subs.graceLeft(subscribers, Date.now()));
            graceTimer.restart();
        }
    }

    // The offset of a zone in seconds, NaN when Plasma does not know the zone.
    function offsetOf(zone) {
        return zone === "local" ? localOffset : offsets[zone] !== undefined ? offsets[zone] : NaN;
    }

    // loading until Plasma has answered, error when it does not know the zone.
    function zoneState(zone) {
        return zone === "local" ? (localZone.length > 0 ? "ready" : "loading") : offsets[zone] === undefined ? "loading" : isNaN(offsets[zone]) ? "error" : "ready";
    }

    function recompute() {
        const faces = host.item as ClockHost;
        if (!faces)
            return ;
        const local = faces.local;
        nowMs = local.dateTime.getTime();
        localOffset = ClockFormat.parseOffset(local.timeZoneOffset);
        localZone = String(local.timeZone);
        const next = {};
        const clocks = faces.zoneClocks;
        const zones = service.zones;
        for (let i = 0; i < clocks.count; ++i) {
            const clock = clocks.objectAt(i) as PlasmaClock.Clock;
            next[zones[i]] = clock.valid ? ClockFormat.parseOffset(clock.timeZoneOffset) : NaN;
        }
        offsets = next;
    }

    onZonesChanged: Qt.callLater(recompute)

    Timer {
        id: graceTimer

        onTriggered: service.syncActive()
    }

    component ClockHost: Item {
        property alias local: localClock
        property alias zoneClocks: zoneClocks

        PlasmaClock.Clock {
            id: localClock

            onTimeChanged: service.recompute()
        }

        Instantiator {
            id: zoneClocks

            model: service.zones
            onObjectAdded: service.recompute()
            onObjectRemoved: service.recompute()

            delegate: PlasmaClock.Clock {
                required property string modelData

                timeZone: modelData
            }
        }

        Component.onCompleted: service.recompute()
    }

    Loader {
        id: host

        active: service.active
        sourceComponent: ClockHost {
        }
    }
}
