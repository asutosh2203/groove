pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents
import "../logic/LiveGlyphs.js" as LiveGlyphs

// One agent session as a full tile (D-57, D-46 style): glyph, project, what it is doing, the task bar when there is a
// task list, and the elapsed minutes. Nothing animates while it works: the changing status line is the signal (P9).
// Colour marks only "needs you" (D-45). It fills whatever slot it is given.
Rectangle {
    id: tile

    required property var app
    required property string sid
    // An accordion row opened in place also shows a chevron that closes it again.
    property bool collapsible: false
    signal collapse()

    readonly property var session: tile.app.agents.byId(tile.sid)
    readonly property bool waiting: tile.session?.state === "waiting"
    readonly property bool finished: tile.session?.state === "done"
    readonly property bool hasTasks: tile.session ? Agents.hasTasks(tile.session) : false
    readonly property bool clickable: tile.app.agents.raisable[tile.sid] === true
    readonly property color accent: Agents.accentFor(tile.session?.agent ?? "", T.agentAccents, T.agentAccentDefault)
    readonly property string host: tile.app.agents.hostNames[tile.sid] ?? ""
    readonly property int minutes: tile.session ? Agents.minutes(tile.session, tile.app.agents.nowMs) : 1

    radius: T.radiusInner
    color: clickable && hover.hovered ? T.rowHover : T.row

    Behavior on color {
        enabled: !tile.app.reduceMotion

        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    // The body raises the window that hosts the session; a tile with no such window does not react to the pointer.
    HoverHandler {
        id: hover

        enabled: tile.clickable
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: tile.clickable
        onClicked: tile.app.openAgent(tile.sid)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: T.liveTilePadding
        spacing: T.liveGap

        RowLayout {
            Layout.fillWidth: true
            spacing: T.liveGap

            Rectangle {
                Layout.preferredWidth: T.liveChip
                Layout.preferredHeight: T.liveChip
                radius: T.radiusInner
                color: T.card
                border.color: T.border
                border.width: 1

                CC.ThemeGlyph {
                    anchors.centerIn: parent
                    width: T.liveGlyph
                    height: T.liveGlyph
                    names: LiveGlyphs.chain(tile.finished ? "agentDone" : tile.waiting ? "agentWaiting" : "agent")
                    color: T.iconIdle
                }

                Rectangle {
                    visible: tile.waiting
                    width: T.liveBadge
                    height: T.liveBadge
                    radius: width / 2
                    color: tile.accent
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: T.liveBadgeInset
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: tile.session?.project ?? ""
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: tile.waiting ? tile.app.strings.agentNeedsOk : tile.finished ? (tile.session?.lastMessage ?? "") : tile.hasTasks && tile.session.task ? tile.session.task : tile.app.strings.agentSubtitle(tile.session?.name ?? "", tile.host)
                    color: tile.waiting ? tile.accent : T.textSecondary
                    font.pixelSize: T.fontCaption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            PlasmaLabel {
                visible: tile.hasTasks
                Layout.rightMargin: tile.collapsible ? T.deckCapsuleItem : 0
                text: tile.session ? tile.app.strings.agentProgress(tile.session.done, tile.session.total) : ""
                color: T.textCaption
                font.pixelSize: T.fontCaption
            }
        }

        Item {
            Layout.fillHeight: true
        }

        ProgressBar {
            visible: tile.hasTasks && !tile.finished
            Layout.fillWidth: true
            Layout.preferredHeight: T.liveRowBar
            from: 0
            to: 1
            value: tile.session ? Agents.progress(tile.session) : 0
            accent: T.fill
            trackColor: T.track
            tipGradient: true
            glow: true
            dimmed: tile.waiting
        }

        RowLayout {
            Layout.fillWidth: true

            PlasmaLabel {
                Layout.fillWidth: true
                text: !tile.session ? "" : tile.finished ? tile.app.strings.agentDone(tile.minutes) : tile.waiting ? tile.app.strings.agentWants(tile.session.waitingAction, tile.session.waitingCommand) : tile.app.strings.agentAction(tile.session.action, tile.session.target)
                color: T.textTertiary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                visible: !tile.finished && !tile.waiting
                text: tile.app.strings.agentMinutes(tile.minutes)
                color: T.textCaption
                font.pixelSize: T.fontCaption
            }
        }
    }

    // Closes an opened accordion row (its own click target).
    Item {
        visible: tile.collapsible
        anchors.top: parent.top
        anchors.right: parent.right
        width: T.deckCapsuleItem
        height: T.deckCapsuleItem
        Accessible.role: Accessible.Button
        Accessible.name: tile.app.strings.jobCollapse

        CC.ThemeGlyph {
            anchors.centerIn: parent
            width: T.deckGlyph
            height: T.deckGlyph
            names: ["go-up-symbolic", "arrow-up", "go-up"]
            color: chevronHover.hovered ? T.textPrimary : T.textTertiary
        }

        HoverHandler {
            id: chevronHover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: tile.collapse()
        }
    }
}
