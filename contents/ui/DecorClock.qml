import QtQuick

// One shared low-rate clock for every decorative loop (weather icon, AudioBars, Control Center bars).
// Items bind their pose to `time` instead of running their own display-rate animations, so the panel is redrawn
// at this clock's rate. Nothing ticks while no item holds a lease (see DecorClockLease), so an idle island
// costs nothing (D-34).
Item {
    id: clock

    // Current time in ms; changes `fps` times a second while at least one lease is held.
    property real time: Date.now()
    // Rates currently requested by lease holders; the clock runs at the highest one.
    property var rates: []
    readonly property int fps: rates.length > 0 ? Math.max.apply(null, rates) : 8
    readonly property bool running: rates.length > 0

    function acquire(rate) {
        const next = rates.slice();
        next.push(rate);
        rates = next;
    }

    function release(rate) {
        const next = rates.slice();
        const i = next.indexOf(rate);
        if (i >= 0)
            next.splice(i, 1);
        rates = next;
    }

    Timer {
        interval: Math.round(1000 / clock.fps)
        running: clock.running
        repeat: true
        onRunningChanged: if (running) clock.time = Date.now()
        onTriggered: clock.time = Date.now()
    }
}
