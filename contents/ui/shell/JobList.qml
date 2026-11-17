pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/Accordion.js" as Accordion
import "../logic/LiveGlyphs.js" as LiveGlyphs

// The agents and jobs as a list (D-52, accordion D-53): the agents' compact rows, then a summary header and the jobs' compact rows (name, percent, thin bar). It scrolls when the rows
// overflow, with a fade where more lie beyond.
Item {
    id: list

    required property var app
    required property var model
    // The agent sessions (D-57), their compact rows above the file jobs; empty when there are none.
    required property var agents
    required property var header

    // Opening a row scrolls just enough to keep it fully in view; a row opened past the Tall cap would otherwise
    // grow below the visible part.
    function keepOpenInView() {
        const ids = [];
        for (let i = 0; i < list.model.count; ++i)
            ids.push(list.model.get(i).jid);
        const target = Accordion.scrollTarget(ids, list.app.deck.openJob, rows.contentY, rows.height, T.liveRowHeight, T.liveTileHeight, rows.spacing);
        if (target !== rows.contentY)
            rows.pinnedTop = false;
        if (target !== rows.contentY)
            scrollAnimation.to = target;
        if (target !== rows.contentY)
            scrollAnimation.restart();
    }

    Item {
        anchors.fill: parent

        ListView {
            id: rows

            anchors.fill: parent
            clip: true
            spacing: T.liveGap
            boundsBehavior: Flickable.StopAtBounds
            model: list.model
            // The header's rows arrive after the view has placed itself, which would leave it scrolled past them; it
            // stays at the top until the user scrolls or a row is opened.
            property bool pinnedTop: true

            onOriginYChanged: {
                if (rows.pinnedTop)
                    rows.positionViewAtBeginning();
            }
            onMovementStarted: rows.pinnedTop = false

            // The agents' rows and the transfers header scroll with the jobs, so a crowded page never hides the jobs.
            header: ColumnLayout {
                width: ListView.view.width
                spacing: T.liveGap

                Repeater {
                    model: list.agents

                    delegate: AgentEntry {
                        Layout.fillWidth: true
                        app: list.app
                    }
                }

                // The transfers group: its header counts file jobs only, and is absent when there are none.
                RowLayout {
                    visible: list.header.count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: T.liveHeaderHeight
                    spacing: T.liveGap

                    CC.ThemeGlyph {
                        Layout.preferredWidth: T.fontBody
                        Layout.preferredHeight: T.fontBody
                        names: LiveGlyphs.chain(list.header.kind === "mixed" ? "transfer" : list.header.kind)
                        color: T.textPrimary
                    }

                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: list.app.strings.liveHeader(list.header.kind, list.header.count)
                        color: T.textPrimary
                        font.pixelSize: T.fontBody
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    PlasmaLabel {
                        text: list.app.strings.jobProgress(list.header.percent, list.header.remaining)
                        color: T.textCaption
                        font.pixelSize: T.fontCaption
                    }
                }

                Item {
                    visible: list.header.count > 0
                    Layout.preferredHeight: 0
                }
            }

            NumberAnimation {
                id: scrollAnimation

                target: rows
                property: "contentY"
                duration: list.app.reduceMotion ? 0 : T.motionPage
                easing.type: T.easingStandard
            }

            Connections {
                function onOpenJobChanged() {
                    if (list.app.deck.openJob !== "")
                        list.keepOpenInView();
                }

                target: list.app.deck
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

            delegate: Rectangle {
                id: entry

                required property int row
                required property string jid
                readonly property bool open: list.app.deck.openJob === entry.jid
                readonly property int percentage: list.app.jobs.percentage(entry.row)

                width: ListView.view.width
                height: entry.open ? T.liveTileHeight : T.liveRowHeight
                radius: T.radiusInner
                color: !entry.open && compactHover.hovered ? T.rowHover : T.row
                clip: true

                Behavior on height {
                    enabled: !list.app.reduceMotion

                    NumberAnimation {
                        duration: T.motionPage
                        easing.type: T.easingStandard
                    }
                }

                Behavior on color {
                    enabled: !list.app.reduceMotion

                    ColorAnimation {
                        duration: T.motionHover
                        easing.type: T.easingStandard
                    }
                }

                // The compact row: a click opens it in place (one at a time).
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
                        onClicked: list.app.deck.toggleJob(entry.jid)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: T.liveTilePadding
                        anchors.rightMargin: T.liveTilePadding
                        anchors.topMargin: T.deckSpacing
                        anchors.bottomMargin: T.deckSpacing
                        spacing: T.liveGap

                        CC.ThemeGlyph {
                            visible: list.header.rowGlyphs
                            Layout.preferredWidth: T.fontBody
                            Layout.preferredHeight: T.fontBody
                            names: list.app.jobs.glyphNames(entry.row)
                            color: T.textSecondary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: T.deckSpacing

                            PlasmaLabel {
                                Layout.fillWidth: true
                                text: list.app.jobTitle(entry.row)
                                color: T.textPrimary
                                font.pixelSize: T.fontCaption
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            ProgressBar {
                                Layout.fillWidth: true
                                Layout.preferredHeight: T.liveRowBar
                                from: 0
                                to: 100
                                value: Math.max(0, entry.percentage)
                                accent: T.fill
                                trackColor: T.track
                                dimmed: list.app.jobs.isSuspended(entry.row)
                            }
                        }

                        PlasmaLabel {
                            text: entry.percentage >= 0 ? entry.percentage + "%" : ""
                            color: T.textCaption
                            font.pixelSize: T.fontCaption
                        }
                    }
                }

                // The opened row is a full tile: its body opens the destination, the chevron closes it.
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

                    sourceComponent: JobTile {
                        app: list.app
                        row: entry.row
                        collapsible: true
                        onCollapse: list.app.deck.toggleJob(entry.jid)
                    }
                }
            }
        }
    }

    // More rows lie beyond: a fade over the last rows and a chevron say so.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: T.liveFadeMore
        visible: !rows.atYEnd
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.75
                color: T.dialog
            }
        }

        CC.ThemeGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: T.fontBody
            height: T.fontBody
            names: ["go-down-symbolic", "arrow-down", "go-down"]
            color: T.textSecondary
        }
    }
}
