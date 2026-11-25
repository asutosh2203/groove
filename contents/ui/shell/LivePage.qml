pragma ComponentBehavior: Bound

import QtQuick
import "../activities" as Activities
import "../controlcenter/Tokens.js" as T

// The Live page (D-52): media is always the card on top; jobs are full tiles when they fit, else a list (LiveLayout.js
// decides). The Tall page is two fixed slots, so content always fills one.
Item {
    id: page

    required property var app
    readonly property var layout: page.app.deck.liveLayout
    readonly property bool list: layout.mode === "list"
    readonly property bool tiles: layout.mode === "tiles"
    // Two equal slots without media; the media card always keeps its Small-page height and the jobs take the rest.
    readonly property real slotHeight: layout.shape === "tall" ? (height - T.liveGap) / 2 : height
    readonly property real mediaHeight: layout.mediaSlot && layout.shape === "tall" ? page.app.deck.mediaHeight : slotHeight
    // The jobs' area: below the media card (with room for the hairline in list mode), else the whole page.
    readonly property real mediaGap: list ? T.liveMediaGap : T.liveGap
    readonly property real trayY: layout.trayArea === "bottom" ? mediaHeight + mediaGap : 0
    readonly property real trayHeight: layout.trayArea === "bottom" ? height - trayY : height

    // One model per view, keyed by id, so a finishing job leaves with a fade and its progress ticks do not rebuild any
    // row: every item (the tiles), the agents and the file jobs (the list's two groups). An agent's id is "agent:<sid>".
    ListModel {
        id: itemsModel
    }

    ListModel {
        id: agentsModel
    }

    ListModel {
        id: timersModel
    }

    ListModel {
        id: jobsModel
    }

    function sync(model, items) {
        for (let i = model.count - 1; i >= 0; --i) {
            if (!items.some(it => it.id === model.get(i).jid))
                model.remove(i);
        }
        for (let k = 0; k < items.length; ++k) {
            let at = -1;
            for (let i = k; i < model.count; ++i) {
                if (model.get(i).jid === items[k].id) {
                    at = i;
                    break;
                }
            }
            const fields = { "jid": items[k].id, "row": items[k].row ?? -1, "kind": items[k].kind, "sid": items[k].sid ?? "" };
            if (at < 0) {
                model.insert(k, fields);
            } else {
                if (at !== k)
                    model.move(at, k, 1);
                model.setProperty(k, "row", fields.row);
            }
        }
    }

    function syncAll() {
        const items = page.layout.items;
        page.sync(itemsModel, items);
        page.sync(agentsModel, items.filter(it => it.kind === "agent"));
        page.sync(timersModel, items.filter(it => it.kind === "timer"));
        page.sync(jobsModel, items.filter(it => it.kind === "job"));
    }

    onLayoutChanged: page.syncAll()
    Component.onCompleted: page.syncAll()

    Item {
        y: 0
        width: page.width
        height: page.mediaHeight
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

    Rectangle {
        y: page.mediaHeight + T.liveMediaGap / 2
        width: page.width
        height: 1
        color: Qt.alpha(T.borderStrong, T.liveHairlineAlpha)
        opacity: page.list && page.layout.mediaSlot ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
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
        model: itemsModel
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

        delegate: Loader {
            id: cell

            required property int row
            required property string kind
            required property string sid

            width: ListView.view.width
            height: page.layout.mediaSlot ? page.trayHeight : page.slotHeight
            sourceComponent: cell.kind === "agent" ? agentTile : cell.kind === "timer" ? timerTile : jobTile

            Component {
                id: jobTile

                JobTile {
                    app: page.app
                    row: cell.row
                }
            }

            Component {
                id: timerTile

                TimerTile {
                    app: page.app
                    pid: cell.sid
                }
            }

            Component {
                id: agentTile

                AgentTile {
                    app: page.app
                    sid: cell.sid
                }
            }
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
            agents: agentsModel
            timers: timersModel
            header: page.layout.header ?? ({ "kind": "mixed", "count": 0, "percent": -1, "remaining": -1, "rowGlyphs": true })
        }
    }
}
