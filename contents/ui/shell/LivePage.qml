pragma ComponentBehavior: Bound

import QtQuick
import "../activities" as Activities
import "../controlcenter/Tokens.js" as T

// The Live page (D-51): media is always the card on top; jobs are full tiles when they fit, else a list (LiveLayout.js
// decides). The Tall page is two fixed slots, so content always fills one.
Item {
    id: page

    required property var app
    readonly property var layout: page.app.deck.liveLayout
    readonly property real slotHeight: layout.shape === "tall" ? (height - T.liveGap) / 2 : height
    // The jobs' area: the bottom slot under media, else the whole page.
    readonly property real trayY: layout.trayArea === "bottom" ? slotHeight + T.liveGap : 0
    readonly property real trayHeight: layout.trayArea === "bottom" ? slotHeight : height
    readonly property bool tiles: layout.mode === "tiles"
    readonly property bool list: layout.mode === "list"

    // One model for both views, keyed by notification id, so a finishing job leaves with a fade and its progress ticks do
    // not rebuild any row.
    ListModel {
        id: jobsModel
    }

    function sync(jobs) {
        for (let i = jobsModel.count - 1; i >= 0; --i) {
            if (!jobs.some(j => j.id === jobsModel.get(i).jid))
                jobsModel.remove(i);
        }
        for (let k = 0; k < jobs.length; ++k) {
            let at = -1;
            for (let i = k; i < jobsModel.count; ++i) {
                if (jobsModel.get(i).jid === jobs[k].id) {
                    at = i;
                    break;
                }
            }
            if (at < 0) {
                jobsModel.insert(k, { "jid": jobs[k].id, "row": jobs[k].row });
            } else {
                if (at !== k)
                    jobsModel.move(at, k, 1);
                jobsModel.setProperty(k, "row", jobs[k].row);
            }
        }
    }

    onLayoutChanged: page.sync(page.layout.jobs)
    Component.onCompleted: page.sync(page.layout.jobs)

    Item {
        y: 0
        width: page.width
        height: page.slotHeight
        opacity: page.layout.mediaSlot ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        Loader {
            anchors.fill: parent
            active: page.layout.mediaSlot
            sourceComponent: Activities.MusicExpanded {
                app: page.app
            }
        }
    }

    ListView {
        id: tilesView

        y: page.trayY
        width: page.width
        height: page.trayHeight
        interactive: false
        spacing: T.liveGap
        model: jobsModel
        opacity: page.tiles ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        delegate: JobTile {
            app: page.app
            width: ListView.view.width
            height: page.slotHeight
        }
    }

    Loader {
        y: page.trayY
        width: page.width
        height: page.trayHeight
        active: page.list || opacity > 0
        opacity: page.list ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        sourceComponent: JobList {
            app: page.app
            model: jobsModel
            header: page.layout.header ?? ({ "kind": "mixed", "count": 0, "percent": -1, "remaining": -1, "rowGlyphs": true })
        }
    }
}
