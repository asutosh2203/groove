pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents
import "../logic/LiveGlyphs.js" as LiveGlyphs

// An agent in the Live list (D-57, accordion D-53): a compact row (glyph, project and what it does, "3 of 7" or the
// minutes, a thin bar when there is a task list) that opens in place into the full AgentTile.
Rectangle {
    id: entry

    required property var app
    required property string sid
    readonly property string jid: "agent:" + entry.sid
    readonly property bool open: entry.app.deck.openJob === entry.jid
    readonly property var session: entry.app.agents.byId(entry.sid)
    readonly property bool waiting: entry.session?.state === "waiting"
    readonly property bool finished: entry.session?.state === "done"
    readonly property bool hasTasks: entry.session ? Agents.hasTasks(entry.session) : false
    readonly property color accent: Agents.accentFor(entry.session?.agent ?? "", T.agentAccents, T.agentAccentDefault)

    height: entry.open ? T.liveTileHeight : T.liveRowHeight
    // The header's layout sizes rows by preferred height and would not follow an animated `height`: rows below would
    // overlap an opened one and the list would not be tall enough to scroll to it.
    Layout.preferredHeight: entry.height
    radius: T.radiusInner
    color: !entry.open && compactHover.hovered ? T.rowHover : T.row
    clip: true

    Behavior on height {
        enabled: !entry.app.reduceMotion

        NumberAnimation {
            duration: T.motionPage
            easing.type: T.easingStandard
        }
    }

    Behavior on color {
        enabled: !entry.app.reduceMotion

        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    Item {
        anchors.fill: parent
        opacity: entry.open ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        HoverHandler {
            id: compactHover

            enabled: !entry.open
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: entry.app.deck.toggleJob(entry.jid)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: T.liveTilePadding
            anchors.rightMargin: T.liveTilePadding
            anchors.topMargin: T.deckSpacing
            anchors.bottomMargin: T.deckSpacing
            spacing: T.liveGap

            Item {
                Layout.preferredWidth: T.fontBody
                Layout.preferredHeight: T.fontBody

                CC.ThemeGlyph {
                    anchors.fill: parent
                    names: LiveGlyphs.chain(entry.finished ? "agentDone" : entry.waiting ? "agentWaiting" : "agent")
                    color: T.textSecondary
                }

                Rectangle {
                    visible: entry.waiting
                    width: T.liveBadgeRow
                    height: T.liveBadgeRow
                    radius: width / 2
                    color: entry.accent
                    anchors.top: parent.top
                    anchors.right: parent.right
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: T.deckSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaLabel {
                        text: entry.session?.project ?? ""
                        color: T.textPrimary
                        font.pixelSize: T.fontCaption
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.maximumWidth: entry.width / 2
                    }

                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: !entry.session ? "" : " · " + (entry.finished ? entry.app.strings.agentDone(Agents.minutes(entry.session, entry.app.agents.nowMs)) : entry.waiting ? entry.app.strings.agentNeedsOk : entry.app.strings.agentAction(entry.session.action, entry.session.target))
                        color: entry.waiting ? entry.accent : T.textSecondary
                        font.pixelSize: T.fontCaption
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                ProgressBar {
                    visible: entry.session !== null && Agents.barMode(entry.session, entry.app.agents.nowMs) !== "none" && !entry.finished
                    Layout.fillWidth: true
                    Layout.preferredHeight: T.liveRowBar
                    from: 0
                    to: 1
                    value: entry.session ? Agents.barValue(entry.session, entry.app.agents.nowMs) : 0
                    accent: T.fill
                    trackColor: T.track
                    dimmed: entry.waiting
                }
            }

            PlasmaLabel {
                visible: !entry.finished
                text: !entry.session ? "" : entry.hasTasks ? entry.app.strings.agentProgress(entry.session.done, entry.session.total) : entry.app.strings.agentMinutes(Agents.minutes(entry.session, entry.app.agents.nowMs))
                color: T.textCaption
                font.pixelSize: T.fontCaption
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: entry.open || opacity > 0
        opacity: entry.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }

        sourceComponent: AgentTile {
            app: entry.app
            sid: entry.sid
            collapsible: true
            onCollapse: entry.app.deck.toggleJob(entry.jid)
        }
    }
}
