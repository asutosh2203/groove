pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../weather"
import "../controlcenter/Tokens.js" as T
import "../logic/DeckPlan.js" as DeckPlan
import "../logic/ReplyShelf.js" as ReplyShelf
import "editor"

MouseArea {
    id: popupRoot

    required property var app
    required property Component controlPage

    property real morph: popupRoot.app.islandOpen ? 1 : 0
    readonly property real contentOpacity: Math.max(0, Math.min(1, (morph - 0.42) / 0.58))
    readonly property real compactOpacity: Math.max(0, Math.min(1, (0.34 - morph) / 0.34))
    readonly property real collapsedWidth: popupRoot.app.realIslandWidth
    readonly property real collapsedHeight: popupRoot.app.realIslandHeight
    // The silhouette morphs to the page size (D-51); the window itself is fixed. With reduced motion it snaps.
    readonly property bool reduceMotion: Kirigami.Units.longDuration <= 1
    property real pageWidth: popupRoot.app.pageWidth
    property real pageHeight: popupRoot.app.pageBaseHeight
    // The shape is the page body plus the notch's ears (zero for the pill); content is laid out in the body.
    readonly property real earSide: popupRoot.app.shapeEars / 2
    readonly property real shapeWidth: popupRoot.pageWidth + popupRoot.app.shapeEars
    readonly property real panelWidth: collapsedWidth + (popupRoot.shapeWidth - collapsedWidth) * morph
    readonly property real panelHeight: collapsedHeight + (popupRoot.pageHeight - collapsedHeight) * morph + popupRoot.shelfExtent
    readonly property real collapsedRadius: popupRoot.app.notchShape ? popupRoot.app.notchBottomRadius : collapsedHeight / 2
    // D-56: the island zooms about 104% on a soft spring while the edit mode is open (none with reduced motion).
    readonly property real zoomTarget: !popupRoot.reduceMotion && popupRoot.app.editor.active && popupRoot.app.popupMode === "deck" && popupRoot.morph >= 1 ? T.editZoom : 1
    property real zoom: popupRoot.zoomTarget
    readonly property real shelfExtent: popupRoot.app.replyShelfHeight * popupRoot.app.replyShelf.progress
    readonly property bool control: popupRoot.app.ccShowing
    readonly property var pageInsets: popupRoot.insets(popupRoot.control)
    readonly property real contentLeft: popupRoot.earSide + popupRoot.pageInsets.l
    readonly property real contentRight: popupRoot.earSide + popupRoot.pageInsets.r
    readonly property real contentTop: popupRoot.pageInsets.t
    readonly property real contentBottom: popupRoot.pageInsets.b

    // The content insets of a page: the Control Center's differ from the other pages'.
    function insets(isControl) {
        return DeckPlan.insets(isControl, T.deckPadding);
    }

    readonly property real panelRadius: collapsedRadius + (popupRoot.app.popupRadius - collapsedRadius) * morph
    readonly property real panelX: popupRoot.app.popupCollapsedX * (1 - morph) + (popupRoot.app.popupWidth - popupRoot.shapeWidth) / 2 * morph
    readonly property real panelY: popupRoot.app.popupCollapsedY * (1 - morph) + (popupRoot.app.islandExpandsUp ? popupRoot.app.popupHeight - popupRoot.pageHeight : 0) * morph

    readonly property bool glowEnabled: popupRoot.app.islandOpen && !popupRoot.app.editor.active && (popupRoot.control ? popupRoot.app.glowControlCenterEnabled : popupRoot.app.glowExpandedEnabled && (popupRoot.app.popupMode === "deck" || popupRoot.app.popupActivityMode() !== "idle"))

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

        if (popupRoot.app.editor.active) {
            if (popupRoot.app.layoutService.dragActive || popupRoot.app.layoutService.resizeActive)
                popupRoot.app.layoutService.resetInteraction();
            else
                popupRoot.app.editor.stepBack();
            event.accepted = true;
            return ;
        }

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
        popupRoot.app.closeFromClick();
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
        transform: Scale {
            origin.x: contentPanel.width / 2
            origin.y: 0
            xScale: popupRoot.zoom
            yScale: popupRoot.zoom
        }

        RoundShape {
            id: roundSurface

            anchors.fill: parent
            visible: !popupRoot.app.notchShape
            radius: popupRoot.panelRadius
            fillTop: popupRoot.control ? T.surfaceControlTop : "#121216"
            fillBottom: popupRoot.control ? T.surfaceControlBottom : "#060608"
            strokeColor: popupRoot.control ? "#25252b" : "#202027"
            rimOpacity: popupRoot.app.rimLight
        }

        // Notch mode: the same silhouette as the collapsed shell, grown downward.
        NotchShape {
            id: notchSurface

            anchors.fill: parent
            visible: popupRoot.app.notchShape
            shoulder: popupRoot.app.notchShoulder
            bottomRadius: popupRoot.panelRadius
            fillTop: popupRoot.control ? T.surfaceControlTop : "#121216"
            fillBottom: popupRoot.control ? T.surfaceControlBottom : "#060608"
            strokeColor: popupRoot.control ? "#25252b" : "#202027"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: popupRoot.app.islandOpen && !popupRoot.app.editor.active
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

        // A deck page lays itself out inside the silhouette (Deck.qml); a pop-in is one expanded view with the same insets.
        Loader {
            anchors.fill: parent
            anchors.leftMargin: popupRoot.app.popupMode === "deck" ? 0 : popupRoot.contentLeft
            anchors.rightMargin: popupRoot.app.popupMode === "deck" ? 0 : popupRoot.contentRight
            anchors.topMargin: popupRoot.app.popupMode === "deck" ? 0 : popupRoot.contentTop
            anchors.bottomMargin: popupRoot.app.popupMode === "deck" ? 0 : popupRoot.contentBottom + popupRoot.shelfExtent
            opacity: popupRoot.contentOpacity
            visible: opacity > 0
            sourceComponent: popupRoot.app.popupMode === "deck" ? (popupRoot.app.editor.active ? editComponent : deckComponent) : popupRoot.app.activities.expandedComponentFor(popupRoot.app.popupActivityMode())
        }

        // The editor lays out at its target size from the first frame and the silhouette morphs around it.
        Component {
            id: editComponent

            Item {
                EditPage {
                    x: (parent.width - width) / 2
                    width: popupRoot.app.deck.editSize ? popupRoot.app.deck.editSize.w : 0
                    height: popupRoot.app.deck.editSize ? popupRoot.app.deck.editSize.h : 0
                    app: popupRoot.app
                    focusRoot: popupRoot
                    controlPage: popupRoot.controlPage
                }
            }
        }

        Component {
            id: deckComponent

            Deck {
                app: popupRoot.app
                popup: popupRoot
                controlPage: popupRoot.controlPage
            }
        }

        IdleContent {
            anchors.fill: parent
            app: popupRoot.app
            primary: false
            sideMargin: popupRoot.earSide + 16
            animate: false
            opacity: popupRoot.app.hasActivity ? 0 : popupRoot.compactOpacity
            visible: opacity > 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: popupRoot.earSide + (popupRoot.app.popupActivityMode() === "media" ? 4 : 6)
            anchors.rightMargin: popupRoot.earSide + 6
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

    // The page-control capsule floats below the island, centred on it and following its bottom edge as it morphs. It
    // appears once the island has finished opening (with a small settle) and goes first on close; it is hidden with one
    // page, in Control Center edit mode and while a pop-in shows.
    DeckCapsule {
        id: capsuleItem

        readonly property bool shown: popupRoot.app.islandOpen && popupRoot.morph > 0.98 && popupRoot.app.popupMode === "deck" && popupRoot.app.deck.capsuleWanted

        app: popupRoot.app
        control: popupRoot.control
        reduceMotion: popupRoot.reduceMotion
        x: popupRoot.panelX + popupRoot.panelWidth / 2 - width / 2
        y: popupRoot.panelY + popupRoot.panelHeight + T.deckCapsuleGap
        opacity: shown ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            y: popupRoot.reduceMotion ? 0 : -T.deckSettle * (1 - capsuleItem.opacity)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }
    }

    Behavior on zoom {
        SpringAnimation {
            spring: 3
            damping: 0.32
            epsilon: 0.0001
        }
    }

    Behavior on pageWidth {
        enabled: !popupRoot.reduceMotion && popupRoot.morph >= 1
        NumberAnimation {
            duration: T.motionPage
            easing.type: T.easingStandard
        }

    }

    Behavior on pageHeight {
        enabled: !popupRoot.reduceMotion && popupRoot.morph >= 1
        NumberAnimation {
            duration: T.motionPage
            easing.type: T.easingStandard
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
