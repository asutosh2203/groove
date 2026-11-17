import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents

// The closed capsule for an agent (D-57, D-38: a job's priority): "groove · 3 of 7", or the minutes without a task list.
// While it waits for you it says so, in the agent's accent (D-45).
Item {
    id: agentCompact

    property var app: null
    readonly property var session: app ? app.agents.primary : null
    readonly property bool waiting: session?.state === "waiting"

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: T.compactInsetLeft
        anchors.rightMargin: T.compactInsetRight
        spacing: T.compactGap

        RowLayout {
            Layout.fillWidth: true
            spacing: T.compactGap

            PlasmaLabel {
                Layout.fillWidth: true
                text: !agentCompact.session ? "" : agentCompact.waiting ? agentCompact.app.strings.agentNeedsOk : agentCompact.session.project
                color: agentCompact.waiting ? Agents.accentFor(agentCompact.session.agent, T.agentAccents, T.agentAccentDefault) : T.textPrimary
                font.pixelSize: T.fontCaption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                visible: agentCompact.session !== null && !agentCompact.waiting
                text: agentCompact.session ? agentCompact.app.strings.agentCompactTail(Agents.compactParts(agentCompact.session, agentCompact.app.agents.nowMs).progress, Agents.minutes(agentCompact.session, agentCompact.app.agents.nowMs)) : ""
                color: T.textCaption
                font.pixelSize: T.fontCaption
                font.weight: Font.DemiBold
            }
        }

        ProgressBar {
            visible: agentCompact.session !== null && Agents.hasTasks(agentCompact.session)
            Layout.fillWidth: true
            Layout.preferredHeight: T.compactBar
            from: 0
            to: 1
            value: agentCompact.session ? Agents.progress(agentCompact.session) : 0
            accent: T.fill
            trackColor: T.track
            dimmed: agentCompact.waiting
        }
    }
}
