pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import "logic/TooltipPlacement.js" as TooltipPlacement

// The one tooltip of the island. The dialog window clips anything outside it, so near a window edge the plain tooltip lost
// half its text: this one is placed each time it shows, flipped below its owner when there is no room above and slid in sideways.
QQC2.ToolTip {
    id: tip

    readonly property var spot: {
        const owner = tip.visible ? tip.parent : null;
        if (!owner || !owner.Window.window)
            return null;
        const at = owner.mapToItem(null, 0, 0);
        const win = owner.Window.window;
        return TooltipPlacement.place({ "x": at.x, "y": at.y, "w": owner.width, "h": owner.height }, { "w": tip.implicitWidth, "h": tip.implicitHeight }, { "w": win.width, "h": win.height }, Math.max(0, tip.margins), 3);
    }

    delay: 350
    x: spot ? spot.x : 0
    y: spot ? spot.y : -tip.implicitHeight - 3
}
