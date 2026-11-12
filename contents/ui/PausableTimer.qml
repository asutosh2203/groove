import QtQuick
import "Countdown.js" as Countdown

// A one-shot timer that can be held: while `hold` is true the countdown stands still, and when it
// is released the timer finishes with the time it had left instead of starting over.
// `running` stays true while held, so callers still see the lifetime as active.
Item {
    id: pausable

    property int duration: 1000
    property bool hold: false
    readonly property bool running: inner.running || held
    property bool held: false
    property var countdown: null

    signal triggered

    function restart() {
        countdown = Countdown.start(Date.now(), duration);
        inner.stop();
        if (hold) {
            countdown = Countdown.pause(countdown, Date.now());
            held = true;
        } else {
            held = false;
            inner.interval = Math.max(1, duration);
            inner.start();
        }
    }

    function stop() {
        inner.stop();
        held = false;
        countdown = null;
    }

    function pause() {
        if (!inner.running)
            return ;
        countdown = Countdown.pause(countdown, Date.now());
        inner.stop();
        held = true;
    }

    function resume() {
        if (!held)
            return ;
        held = false;
        countdown = Countdown.resume(countdown, Date.now());
        inner.interval = Math.max(1, Countdown.remaining(countdown, Date.now()));
        inner.start();
    }

    onHoldChanged: hold ? pause() : resume()

    Timer {
        id: inner

        repeat: false
        onTriggered: {
            pausable.countdown = null;
            pausable.triggered();
        }
    }
}
