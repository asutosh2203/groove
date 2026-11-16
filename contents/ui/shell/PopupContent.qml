pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../weather"
import "../logic/ReplyShelf.js" as ReplyShelf

MouseArea {
    id: popupRoot

    required property var app
    required property Component controlPage

    property real morph: popupRoot.app.islandOpen ? 1 : 0
    readonly property real contentOpacity: Math.max(0, Math.min(1, (morph - 0.42) / 0.58))
    readonly property real compactOpacity: Math.max(0, Math.min(1, (0.34 - morph) / 0.34))
    readonly property real collapsedWidth: popupRoot.app.realIslandWidth
    readonly property real collapsedHeight: popupRoot.app.realIslandHeight
    readonly property real panelWidth: collapsedWidth + (popupRoot.app.popupWidth - collapsedWidth) * morph
    readonly property real panelHeight: collapsedHeight + (popupRoot.app.popupBaseHeight - collapsedHeight) * morph + popupRoot.shelfExtent
    readonly property real collapsedRadius: popupRoot.app.notchShape ? popupRoot.app.notchBottomRadius : collapsedHeight / 2
    readonly property real shelfExtent: popupRoot.app.replyShelfHeight * popupRoot.app.replyShelf.progress
    readonly property real contentLeft: (popupRoot.app.popupMode === "control" ? 14 : 12) + (popupRoot.app.notchShape ? popupRoot.app.notchShoulder + 2 : 0)
    readonly property real contentRight: popupRoot.app.popupMode === "control" ? (popupRoot.app.notchShape ? 22 : contentLeft) : (contentLeft + (popupRoot.app.notchShape ? 0 : 3))
    readonly property real contentBottom: popupRoot.app.popupMode === "control" ? 16 : (popupRoot.app.notchShape ? 14 : 10) - 2
    readonly property real panelRadius: collapsedRadius + (popupRoot.app.popupRadius - collapsedRadius) * morph
    readonly property real panelX: popupRoot.app.popupCollapsedX * (1 - morph)
    readonly property real panelY: popupRoot.app.popupCollapsedY * (1 - morph)

    readonly property bool glowEnabled: popupRoot.app.islandOpen && (popupRoot.app.popupMode === "control" ? popupRoot.app.glowControlCenterEnabled : popupRoot.app.glowExpandedEnabled && popupRoot.app.popupMode === "activity" && popupRoot.app.popupActivityMode() !== "idle")

    implicitWidth: popupRoot.app.popupWidth
    implicitHeight: popupRoot.app.popupHeight
    width: popupRoot.app.popupWidth
    height: popupRoot.app.popupHeight
    Layout.minimumWidth: popupRoot.app.popupWidth
    Layout.maximumWidth: popupRoot.app.popupWidth
    Layout.preferredWidth: popupRoot.app.popupWidth
    Layout.minimumHeight: popupRoot.app.popupHeight
    Layout.maximumHeight: popupRoot.app.popupHeight
    Layout.preferredHeight: popupRoot.app.popupHeight
    hoverEnabled: true
    focus: popupRoot.app.popupAcceptsFocus
    acceptedButtons: Qt.LeftButton
    Accessible.role: Accessible.Grouping
    Accessible.name: popupRoot.app.strings.appTitle
    Accessible.description: popupRoot.app.primaryText() + ". " + popupRoot.app.secondaryText()
    Keys.onPressed: (event) => {
        if (event.key !== Qt.Key_Escape)
            return ;

        if (popupRoot.app.replyShelf.isOpen) {
            popupRoot.app.replyShelf.escapePressed();
            event.accepted = true;
            return ;
        }

        if (popupRoot.app.layoutService.dragActive || popupRoot.app.layoutService.resizeActive)
            popupRoot.app.layoutService.resetInteraction();
        else if (popupRoot.app.layoutService.editMode)
            popupRoot.app.layoutService.cancelEdit();
        else
            popupRoot.app.closeIsland();

        event.accepted = true;
    }
    onClicked: (mouse) => {
        popupRoot.app.closeIsland();
        mouse.accepted = true;
    }
    opacity: 1

    Rectangle {
        id: popupShadow

        x: popupRoot.panelX
        y: popupRoot.panelY
        width: popupRoot.panelWidth
        height: popupRoot.panelHeight
        radius: popupRoot.panelRadius
        color: "#050507"
        opacity: 0
    }

    Rectangle {
        id: contentPanel

        x: popupShadow.x
        y: popupShadow.y
        width: popupShadow.width
        height: popupShadow.height
        radius: popupShadow.radius
        color: "transparent"
        clip: true

        RoundShape {
            id: roundSurface

            anchors.fill: parent
            visible: !popupRoot.app.notchShape
            radius: popupRoot.panelRadius
            fillTop: popupRoot.app.popupMode === "control" ? "#141419" : "#121216"
            fillBottom: popupRoot.app.popupMode === "control" ? "#09090c" : "#060608"
            strokeColor: popupRoot.app.popupMode === "control" ? "#25252b" : "#202027"
            rimOpacity: popupRoot.app.rimLight
        }

        // Notch mode: the same silhouette as the collapsed shell, grown downward.
        NotchShape {
            id: notchSurface

            anchors.fill: parent
            visible: popupRoot.app.notchShape
            shoulder: popupRoot.app.notchShoulder
            bottomRadius: popupRoot.panelRadius
            fillTop: popupRoot.app.popupMode === "control" ? "#141419" : "#121216"
            fillBottom: popupRoot.app.popupMode === "control" ? "#09090c" : "#060608"
            strokeColor: popupRoot.app.popupMode === "control" ? "#25252b" : "#202027"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: popupRoot.app.islandOpen
            propagateComposedEvents: true
            onClicked: (mouse) => {
                popupRoot.app.closeIsland();
                mouse.accepted = false;
            }
        }

        // A HoverHandler is passive, so items above the popup (labels, icons) can't take the hover away
        // the way they did from a MouseArea's containsMouse, which made the highlight flicker.
        HoverHandler {
            id: noticeHover

            enabled: popupRoot.app.islandOpen && popupRoot.app.popupMode === "activity"
            cursorShape: noticeOpenArea.noticeClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        Binding {
            target: popupRoot.app
            property: "noticeHovered"
            value: noticeHover.enabled && noticeHover.hovered && noticeOpenArea.noticeClickable
        }

        Binding {
            target: popupRoot.app
            property: "popupHovered"
            value: noticeHover.enabled && noticeHover.hovered
        }

        MouseArea {
            id: noticeOpenArea

            readonly property int noticeRow: popupRoot.app.popupMode === "activity" && popupRoot.app.popupActivityMode() === "notice" ? popupRoot.app.notifications.latestRow() : -1
            readonly property bool noticeClickable: noticeRow >= 0 && popupRoot.app.notifications.clickable(noticeRow)

            anchors.fill: parent
            enabled: popupRoot.app.islandOpen && noticeClickable
            // Single click opens immediately; the notice popup has no double-click behaviour.
            onClicked: popupRoot.app.notifications.open(noticeRow)
        }

        Loader {
            // The notch body is narrower than the window by its shoulders, so it
            // needs extra side padding (and a bit more top/bottom) to breathe.
            anchors.fill: parent
            anchors.leftMargin: popupRoot.contentLeft
            anchors.rightMargin: popupRoot.contentRight
            anchors.topMargin: popupRoot.app.popupMode === "control" ? 12 : (popupRoot.app.notchShape ? 14 : 10)
            anchors.bottomMargin: popupRoot.contentBottom + popupRoot.shelfExtent
            opacity: popupRoot.contentOpacity
            visible: opacity > 0
            sourceComponent: popupRoot.app.popupMode === "control" ? popupRoot.controlPage : popupRoot.app.activities.expandedComponentFor(popupRoot.app.popupActivityMode())
        }

        IdleContent {
            anchors.fill: parent
            app: popupRoot.app
            primary: false
            sideMargin: popupRoot.app.notchShape ? 18 : 16
            animate: false
            opacity: popupRoot.app.hasActivity ? 0 : popupRoot.compactOpacity
            visible: opacity > 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: popupRoot.app.notchShape ? popupRoot.app.notchSideMargin + 2 : (popupRoot.app.popupActivityMode() === "media" ? 4 : 6)
            anchors.rightMargin: popupRoot.app.notchShape ? popupRoot.app.notchSideMargin : 6
            anchors.topMargin: 4
            anchors.bottomMargin: popupRoot.app.notchShape ? 6 : 4
            spacing: 5
            opacity: popupRoot.compactOpacity
            visible: opacity > 0

            Rectangle {
                Layout.preferredWidth: popupRoot.app.compactArtworkSize
                Layout.preferredHeight: popupRoot.app.compactArtworkSize
                color: "transparent"

                Loader {
                    anchors.fill: parent
                    sourceComponent: popupRoot.app.activities.visualComponentFor(popupRoot.app.popupActivityMode())
                }

            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Loader {
                    anchors.fill: parent
                    active: popupRoot.app.hasActivity
                    sourceComponent: popupRoot.app.activities.compactComponentFor(popupRoot.app.popupActivityMode())
                }

            }

        }

        // D-43: the reply shelf, below the message. It fades in a beat after the island starts growing.
        Item {
            id: shelfItem

            readonly property real reveal: Math.max(0, Math.min(1, (popupRoot.app.replyShelf.progress - 0.35) / 0.5))

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: popupRoot.contentLeft
            anchors.rightMargin: popupRoot.contentRight
            anchors.bottomMargin: popupRoot.contentBottom
            height: 34
            opacity: reveal
            visible: reveal > 0
            transform: Translate {
                y: (1 - shelfItem.reveal) * -8
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.top
                anchors.bottomMargin: 1
                visible: popupRoot.app.replyShelf.error.length > 0
                text: popupRoot.app.strings.replyFailed
                color: "#ff6b6b"
                font.pixelSize: 10
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#1b1b21"
                border.width: 1
                border.color: popupRoot.app.replyShelf.error.length > 0 ? "#ff6b6b" : replyField.activeFocus ? "#5a5a68" : "#2a2a31"
            }

            TextInput {
                id: replyField

                anchors.left: parent.left
                anchors.right: sendButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                color: "#ffffff"
                selectionColor: "#5a5a68"
                font.pixelSize: 12
                clip: true
                activeFocusOnPress: true
                Accessible.name: popupRoot.app.strings.replySend
                onTextChanged: {
                    popupRoot.app.replyShelf.draft = text;
                    popupRoot.app.replyShelf.edited();
                }
                onActiveFocusChanged: popupRoot.app.replyShelf.fieldFocused = activeFocus
                onAccepted: popupRoot.app.replyShelf.send()
                Keys.onEscapePressed: popupRoot.app.replyShelf.escapePressed()

                PlasmaLabel {
                    anchors.fill: parent
                    visible: replyField.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                    text: ReplyShelf.placeholder(popupRoot.app.notifications.replyInfo(popupRoot.app.notifications.latestRow()).placeholder, popupRoot.app.strings.replyPlaceholder(popupRoot.app.notifications.title(popupRoot.app.notifications.latestRow())))
                    color: "#6e707a"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Connections {
                    function onCleared() {
                        replyField.clear();
                    }

                    target: popupRoot.app.replyShelf
                }
            }

            Item {
                id: sendButton

                readonly property bool ready: ReplyShelf.canSend(popupRoot.app.replyShelf.draft)

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 4
                width: 26
                height: 26
                opacity: ready ? 1 : 0.4
                Accessible.role: Accessible.Button
                Accessible.name: popupRoot.app.strings.replySend

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: sendArea.pressed ? "#484852" : sendArea.containsMouse && sendButton.ready ? "#2d2d35" : "#23232a"
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: ReplyShelf.symbolicName(popupRoot.app.notifications.replyInfo(popupRoot.app.notifications.latestRow()).submitIcon) || "mail-send-symbolic"
                    fallback: "mail-send-symbolic"
                    isMask: true
                    color: "#ffffff"
                }

                MouseArea {
                    id: sendArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: sendButton.ready
                    onClicked: popupRoot.app.replyShelf.send()
                }
            }
        }

        // Cursor glow (D-41) on every expanded surface: the notice cue is this glow plus the open glyph. A passive HoverHandler, so children keep their own hover and clicks.
        HoverHandler {
            id: glowHover

            enabled: popupRoot.glowEnabled
        }

        // HoverHandler gets no events while a button is held, so a passive PointHandler follows the pointer through
        // slider and tile drags. It only observes (no exclusive grab), so the drag keeps behaving as before.
        PointHandler {
            id: glowPoint

            enabled: popupRoot.glowEnabled
            acceptedButtons: Qt.AllButtons
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        }

        CursorGlow {
            id: cursorGlow

            anchors.fill: parent
            mask: popupRoot.app.notchShape ? notchSurface : roundSurface
            hovering: (glowHover.hovered || glowPoint.active) && popupRoot.glowEnabled && !popupRoot.app.replyShelf.isOpen
            pointer: glowPoint.active ? glowPoint.point.position : glowHover.point.position

            Connections {
                function onOpening() {
                    if (popupRoot.glowEnabled)
                        cursorGlow.bloom();
                }

                target: popupRoot.app.replyShelf
            }
        }

        // The popup only takes keyboard focus after an explicit press inside it (never on hover: changing
        // the window flags re-configures the surface). The press is passed on to whatever is underneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (!popupRoot.app.dialogActive)
                    popupRoot.app.focusIslandDialog();
                mouse.accepted = false;
            }
        }

    }

    Behavior on morph {
        NumberAnimation {
            duration: 340
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.82, 0.18, 1, 1, 1]
        }

    }

}
