pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import "../../logic/ClaudeWidget.js" as Claude

// Claude Code 2x1 (D-60): the budget on the left, at most two session rows on the right. Which sessions, and where, is the
// service's sticky Claude.assign. The slots fill the column and are sized by their content; when a row gains or loses its
// accent line the boundary slides. Rows are keyed by session, so activity updates them in place; one that leaves fades out,
// one that arrives fades in, and an older waiting row slides up into a freed top slot.
ClaudeBase {
    id: view

    readonly property real dividerX: view.cellWidth + T.gap / 2
    readonly property real slotX: view.dividerX + T.hoverInset
    readonly property real slotWidth: view.boxWidth - view.slotX - T.hoverInset
    readonly property var infoById: Claude.byId(Claude.rows(view.facts.sessions, view.facts.recent))
    readonly property var wanted: view.agents ? view.agents.rowSlots.slots.filter(id => id !== null && id in view.infoById) : []
    readonly property var layout: Claude.layout(view.wanted.map(id => view.infoById[id]), view.boxHeight, T.widgetPadding, T.hoverInset, probe.implicitHeight, T.widgetHairline, T.deckSpacing)
    // False until the first rows exist: those appear at once, later arrivals fade in.
    property bool synced: false

    onWantedChanged: view.sync()
    Component.onCompleted: view.sync()

    function sync() {
        for (let i = rowsModel.count - 1; i >= 0; --i) {
            const gone = !view.wanted.includes(rowsModel.get(i).sid);
            if (gone && view.reduceMotion)
                rowsModel.remove(i);
            else
                rowsModel.setProperty(i, "leaving", gone);
        }
        for (const id of view.wanted) {
            let present = false;
            for (let i = 0; i < rowsModel.count; ++i)
                present = present || rowsModel.get(i).sid === id;
            if (!present)
                rowsModel.append({ "sid": id, "leaving": false, "fresh": view.synced });
        }
        view.synced = true;
        if (!view.reduceMotion)
            reaper.restart();
    }

    function reap() {
        for (let i = rowsModel.count - 1; i >= 0; --i) {
            if (rowsModel.get(i).leaving)
                rowsModel.remove(i);
        }
    }

    // Same line height as the rows' own labels, so the slots are sized by what they hold.
    Island.PlasmaLabel {
        id: probe

        visible: false
        text: "Ag"
        font.pixelSize: T.fontCaption
    }

    ListModel {
        id: rowsModel
    }

    // Takes rows out once they have faded; it runs only for that moment.
    Timer {
        id: reaper

        interval: T.motionFade + 40
        onTriggered: view.reap()
    }

    LeftBlock {
        width: view.cellWidth
        height: parent.height
        base: view

        // The left block acts like the 1x1.
        MouseArea {
            anchors.fill: parent
            enabled: view.face.target !== null && !!view.agents && view.agents.raisable[view.face.target] === true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.runAction({ "type": "agent", "value": view.face.target })
        }
    }

    Rectangle {
        x: view.dividerX
        y: T.widgetPadding
        width: 1
        height: view.boxHeight - 2 * T.widgetPadding
        color: T.borderStrong
    }

    Repeater {
        model: rowsModel

        delegate: SessionRow {
            id: slot

            required property string sid
            required property bool leaving
            required property bool fresh
            readonly property var current: view.infoById[slot.sid]
            // The last facts, kept while the row fades out after its session has gone.
            property var last: null
            property int kept: 0
            readonly property int at: view.wanted.indexOf(slot.sid)
            readonly property int place: Math.min(slot.at >= 0 ? slot.at : slot.kept, view.layout.heights.length - 1)
            property bool born: false

            info: slot.current ?? slot.last
            base: view
            x: view.slotX
            width: view.slotWidth
            y: view.layout.tops[slot.place] ?? 0
            height: view.layout.heights[slot.place] ?? 0
            opacity: slot.leaving || (slot.fresh && !slot.born) ? 0 : 1
            scale: slot.lifted ? T.widgetRowLift : 1
            z: slot.lifted ? 2 : 0

            onCurrentChanged: {
                if (slot.current)
                    slot.last = slot.current;
            }
            onAtChanged: {
                if (slot.at < 0)
                    return;
                if (!view.reduceMotion && slot.at < slot.kept)
                    slot.lifted = true;
                slot.kept = slot.at;
            }
            Component.onCompleted: {
                slot.last = slot.current;
                slot.kept = Math.max(0, slot.at);
                slot.born = true;
            }

            Behavior on y {
                enabled: !view.reduceMotion

                NumberAnimation {
                    duration: T.motionPage
                    easing.type: T.easingStandard
                }
            }

            Behavior on height {
                enabled: !view.reduceMotion

                NumberAnimation {
                    duration: T.motionPage
                    easing.type: T.easingStandard
                }
            }

            Behavior on opacity {
                enabled: !view.reduceMotion

                NumberAnimation {
                    duration: T.motionFade
                    easing.type: T.easingStandard
                }
            }

            Behavior on scale {
                enabled: !view.reduceMotion

                NumberAnimation {
                    duration: T.motionFade
                    easing.type: T.easingStandard
                }
            }

            Timer {
                interval: T.motionPage
                running: slot.lifted
                onTriggered: slot.lifted = false
            }
        }
    }

    Island.PlasmaLabel {
        x: view.slotX
        width: view.slotWidth
        height: view.height
        visible: view.wanted.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: view.strings ? view.strings.claudeNoRecent : ""
        color: T.textTertiary
        font.pixelSize: T.fontBody
    }
}
