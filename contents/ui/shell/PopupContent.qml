pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../weather"

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
    readonly property real panelHeight: collapsedHeight + (popupRoot.app.popupHeight - collapsedHeight) * morph
    readonly property real collapsedRadius: popupRoot.app.notchShape ? popupRoot.app.notchBottomRadius : collapsedHeight / 2
    readonly property real panelRadius: collapsedRadius + (popupRoot.app.popupRadius - collapsedRadius) * morph
    readonly property real panelX: popupRoot.app.popupCollapsedX * (1 - morph)
    readonly property real panelY: popupRoot.app.popupCollapsedY * (1 - morph)

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

        // Clickable notice popup (D-31): the whole island is the target, so the highlight and hit area
        // follow the shell silhouette instead of the inset content area.
        RoundShape {
            anchors.fill: parent
            visible: !popupRoot.app.notchShape && opacity > 0
            opacity: noticeHover.hovered && noticeOpenArea.noticeClickable ? 1 : 0
            radius: popupRoot.panelRadius
            fillTop: "#14ffffff"
            fillBottom: "#0cffffff"
            strokeColor: "transparent"

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        NotchShape {
            anchors.fill: parent
            visible: popupRoot.app.notchShape && opacity > 0
            opacity: noticeHover.hovered && noticeOpenArea.noticeClickable ? 1 : 0
            shoulder: popupRoot.app.notchShoulder
            bottomRadius: popupRoot.panelRadius
            fillTop: "#14ffffff"
            fillBottom: "#0cffffff"
            strokeColor: "transparent"

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
            anchors.leftMargin: (popupRoot.app.popupMode === "control" ? 14 : 12) + (popupRoot.app.notchShape ? popupRoot.app.notchShoulder + 2 : 0)
            anchors.rightMargin: popupRoot.app.popupMode === "control" ? (popupRoot.app.notchShape ? 22 : anchors.leftMargin) : (anchors.leftMargin + (popupRoot.app.notchShape ? 0 : 3))
            anchors.topMargin: popupRoot.app.popupMode === "control" ? 12 : (popupRoot.app.notchShape ? 14 : 10)
            anchors.bottomMargin: popupRoot.app.popupMode === "control" ? 16 : anchors.topMargin - 2
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
