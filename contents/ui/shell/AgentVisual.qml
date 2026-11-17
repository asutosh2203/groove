pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/Agents.js" as Agents
import "../logic/LiveGlyphs.js" as LiveGlyphs

// The compact face of an agent (D-57): the prompt glyph, with the accent dot while it waits for you (D-45).
Item {
    id: self

    required property var app
    readonly property var session: self.app.agents.primary
    readonly property bool waiting: self.session?.state === "waiting"

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: T.card
        border.color: T.border
        border.width: 1
    }

    CC.ThemeGlyph {
        anchors.fill: parent
        anchors.margins: Math.max(3, self.width * 0.22)
        names: LiveGlyphs.chain(self.waiting ? "agentWaiting" : "agent")
        color: T.iconIdle
    }

    Rectangle {
        visible: self.waiting
        width: Math.max(T.liveBadge, self.width * 0.26)
        height: width
        radius: width / 2
        color: Agents.accentFor(self.session?.agent ?? "", T.agentAccents, T.agentAccentDefault)
        anchors.top: parent.top
        anchors.right: parent.right
    }
}
