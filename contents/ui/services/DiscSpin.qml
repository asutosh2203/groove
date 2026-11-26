pragma ComponentBehavior: Bound

import QtQuick
import "../logic/DiscSpin.js" as Disc

// The held angle of the Pill's turning artwork (D-68). It lives here, not in the view: the compact view is destroyed
// whenever another activity takes over, and the disc must come back at the angle it stopped at.
QtObject {
    id: service

    property var held: Disc.initial()

    function advance(key, spinning, nowMs) {
        held = Disc.step(held, { "key": key, "spinning": spinning }, nowMs);
    }

    function angleFor(key) {
        return Disc.angleFor(held, key);
    }
}
