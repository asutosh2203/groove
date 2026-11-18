import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents

// The closed capsule for an agent (D-57, D-58, D-38: a job's priority): "groove · 4 min left" or "· 3 of 7" with a bar, "· 2 subagents", else a verb.
// While it waits for you it says so, in the agent's accent (D-45).
Item {
    id: agentCompact

    property var app: null
    readonly property var session: app ? app.agents.primary : null
    readonly property bool waiting: session?.state === "waiting"
    // The service's coarse clock: it steps every 5 s during a countdown and every minute otherwise, never per second.
    readonly property var compact: session ? Agents.compact(session, app.agents.nowMs) : null

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

            Rectangle {
                visible: agentCompact.session !== null && !agentCompact.waiting
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: T.compactDot
                Layout.preferredHeight: T.compactDot
                radius: width / 2
                color: T.textCaption
            }

            RollText {
                visible: agentCompact.session !== null && !agentCompact.waiting
                Layout.alignment: Qt.AlignVCenter
                text: agentCompact.session ? agentCompact.app.strings.agentCompactTail(agentCompact.compact) : ""
                color: T.textCaption
                duration: agentCompact.app.reduceMotion ? 0 : T.motionFade
            }
        }

        ProgressBar {
            visible: agentCompact.compact !== null && (agentCompact.compact.mode === "countdown" || agentCompact.compact.mode === "tasks")
            Layout.fillWidth: true
            Layout.preferredHeight: T.compactBar
            from: 0
            to: 1
            value: agentCompact.session ? Agents.barValue(agentCompact.session, agentCompact.app.agents.nowMs) : 0
            accent: T.fill
            trackColor: T.track
            dimmed: agentCompact.waiting
        }
    }
}
