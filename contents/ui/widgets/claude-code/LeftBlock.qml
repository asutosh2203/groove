pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter" as CC
import "../../controlcenter/Tokens.js" as T
import ".." as Widgets

// The 1x1 face of Claude Code, also the left block of the 2x1 (D-60): label (moon when resting), the hero (a usage ring and
// percent, a cost, a count or the moon) and the detail line. Hovering for a moment peeks one more fact (cross-fade, instant
// with reduced motion). The dwell timer runs only while the pointer is over the block.
Item {
    id: block

    required property var base
    property bool peeking: false
    readonly property var face: block.base.face
    readonly property var s: block.base.strings
    readonly property string kind: block.face.hero.kind
    readonly property bool stale: block.base.staleText.length > 0
    readonly property string detail: block.stale ? block.base.staleText : block.s ? block.detailText(block.face.detail) : ""
    readonly property string peek: block.s ? block.peekText(block.face.peek) : ""
    readonly property bool peekShown: block.peeking && block.peek.length > 0 && !block.stale
    readonly property color accent: T.agentAccents["claude-code"]

    function whenText(d) {
        return d.window === "sevenDay" ? block.base.dayOf(d.resetsAt) : block.base.localTime(d.resetsAt);
    }

    function detailText(d) {
        switch (d.kind) {
        case "limit":
            return block.s.claudeLimit(d.window === "sevenDay", block.whenText(d));
        case "attention":
            return block.s.claudeAttention(d.n);
        case "caughtUp":
            return block.s.claudeCaughtUp;
        case "costSessions":
            return block.s.claudeCostSessions(d.n);
        case "project":
            return d.name;
        }
        return "";
    }

    function peekText(p) {
        if (!p)
            return "";
        switch (p.kind) {
        case "week":
            return block.s.claudeWeek(p.pct, block.base.dayOf(p.resetsAt));
        case "wants":
            return block.s.agentWants(p.action, p.text);
        case "last":
            return block.s.claudeLast(p.project, p.minutes);
        case "terminalOnly":
            return block.s.claudeTerminalOnly;
        }
        return "";
    }

    function heroText(h) {
        switch (h.kind) {
        case "ring":
            return h.pct + "%";
        case "cost":
            return block.s.claudeCost(h.usd);
        case "count":
            return block.s.claudeRunning(h.n);
        }
        return "";
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered)
                dwell.restart();
            else {
                dwell.stop();
                block.peeking = false;
            }
        }
    }

    Timer {
        id: dwell

        interval: T.widgetPeekDwell
        onTriggered: block.peeking = true
    }

    Widgets.TileFace {
        id: tile

        anchors.fill: parent
        anchors.margins: T.widgetPadding
        label: block.s ? block.s.claudeLabel : ""
        labelInset: block.face.moon ? T.widgetLabelGlyph + T.deckSpacing : 0
        hero: block.s ? block.heroText(block.face.hero) : ""
        heroInset: block.kind === "ring" ? T.widgetRing + T.gap : 0
        heroOpacity: block.face.resting ? T.disabledOpacity : 1
        detail: block.detail
        detailItem.color: block.face.detail.kind === "attention" ? block.accent : T.textSecondary
        detailItem.opacity: block.peekShown ? 0 : 1

        Behavior on detailItem.opacity {
            enabled: !block.base.reduceMotion

            NumberAnimation {
                duration: T.motionHover
                easing.type: T.easingStandard
            }
        }

        CC.ThemeGlyph {
            anchors.top: parent.top
            anchors.right: parent.right
            width: T.widgetLabelGlyph
            height: T.widgetLabelGlyph
            visible: block.face.moon
            names: ["kove:moon"]
            color: T.textSecondary
        }

        CC.ThemeGlyph {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: T.widgetHeroSize
            height: T.widgetHeroSize
            visible: block.kind === "moon"
            names: ["kove:moon"]
            color: T.textSecondary
        }

        Ring {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: T.widgetRing
            height: T.widgetRing
            visible: block.kind === "ring"
            pct: block.kind === "ring" ? block.face.hero.pct : 0
            color: block.face.resting ? T.textSecondary : T.textPrimary
        }

        // The resting usage, quiet, in the top right: the bottom line is the detail, which a hover swaps for longer text.
        Column {
            anchors.right: parent.right
            anchors.top: parent.top
            visible: block.face.side !== null && block.face.side.length > 0

            Repeater {
                model: block.face.side ?? []

                delegate: Island.PlasmaLabel {
                    required property var modelData

                    width: T.widgetUsageWidth
                    horizontalAlignment: Text.AlignRight
                    text: block.s ? block.s.claudeUsageShort(modelData.window === "sevenDay", modelData.pct) : ""
                    color: T.textSecondary
                    font.pixelSize: T.fontCaption
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        Island.PlasmaLabel {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            opacity: block.peekShown ? 1 : 0
            text: block.peek
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            // The usage note is a sentence: it wraps to two lines; every other peek is one elided line.
            wrapMode: block.face.peek && block.face.peek.kind === "terminalOnly" ? Text.WordWrap : Text.NoWrap
            maximumLineCount: block.face.peek && block.face.peek.kind === "terminalOnly" ? 2 : 1

            Behavior on opacity {
                enabled: !block.base.reduceMotion

                NumberAnimation {
                    duration: T.motionHover
                    easing.type: T.easingStandard
                }
            }
        }
    }
}
