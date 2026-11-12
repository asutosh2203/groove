import QtQuick

// Holds a place on the shared DecorClock while `active`, and gives it back when inactive or destroyed.
QtObject {
    id: lease

    property var clock: null
    property bool active: false
    property int fps: 8
    property bool held: false
    property var heldClock: null
    property int heldFps: 8

    function sync() {
        const want = active && clock !== null && clock !== undefined;
        if (held && (!want || heldClock !== clock || heldFps !== fps)) {
            heldClock.release(heldFps);
            held = false;
            heldClock = null;
        }
        if (want && !held) {
            clock.acquire(fps);
            held = true;
            heldClock = clock;
            heldFps = fps;
        }
    }

    onActiveChanged: sync()
    onClockChanged: sync()
    onFpsChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held && heldClock)
            heldClock.release(heldFps);
    }
}
