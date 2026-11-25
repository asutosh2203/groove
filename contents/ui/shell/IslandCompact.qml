pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../weather"
import "../controlcenter/Tokens.js" as T

Item {
    id: island

    required property var app

    width: island.app.islandWidth
    height: island.app.islandHeight
    scale: 1
    opacity: island.app.panelHidden ? 0 : 1

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        Accessible.role: Accessible.Button
        Accessible.name: island.app.strings.appTitle
        Accessible.description: island.app.primaryText() + ". " + island.app.secondaryText()
        Accessible.onPressAction: island.app.toggleControlCenter()
        onClicked: (mouse) => {
            island.app.clickButton = mouse.button;
            island.app.idleClickTarget = !island.app.hasActivity && mouse.button === Qt.LeftButton ? idleFace.targetAt(mouse.x, mouse.y) : "";
            // Time/weather launch only after the double-click window, so a double click always wins.
            island.app.scheduleClick(island.app.idleClickTarget !== "" ? Application.styleHints.mouseDoubleClickInterval : 210);
        }
        onDoubleClicked: (mouse) => {
            island.app.cancelClick();
            island.app.toggleControlCenter();
        }
        onWheel: (wheel) => {
            if (island.app.media.player && island.app.media.player.changeVolume)
                island.app.media.player.changeVolume(wheel.angleDelta.y > 0 ? 0.04 : -0.04, true);
            else
                island.app.system.adjustVolume(wheel.angleDelta.y > 0);
        }
    }

    NotchShape {
        anchors.fill: parent
        visible: island.app.notchShape
        shoulder: island.app.notchShoulder
        bottomRadius: island.app.notchBottomRadius
    }

    RoundShape {
        id: capsule

        visible: !island.app.notchShape
        anchors.fill: parent
        rimOpacity: island.app.rimLight
    }

    IdleContent {
        id: idleFace

        anchors.fill: parent
        app: island.app
        sideMargin: island.app.shapeEars / 2 + 16
        animate: !island.app.hasActivity && !island.app.islandOpen && !island.app.panelHidden
        opacity: island.app.hasActivity ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: T.easingStandard }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: island.app.shapeEars / 2 + (island.app.activityMode() === "media" ? 4 : 6)
        anchors.rightMargin: island.app.shapeEars / 2 + 6
        anchors.topMargin: 4
        anchors.bottomMargin: island.app.notchShape ? 6 : 4
        spacing: 5

        Rectangle {
            Layout.preferredWidth: island.app.compactArtworkSize
            Layout.preferredHeight: island.app.compactArtworkSize
            color: "transparent"

            Loader {
                anchors.fill: parent
                sourceComponent: island.app.activities.visualComponentFor(island.app.activityMode())
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                anchors.fill: parent
                active: island.app.hasActivity
                sourceComponent: island.app.activities.compactComponentFor(island.app.activityMode())
            }

        }

    }

    // A timer waiting for play leaves this dot while something else holds the capsule (D-64); the timer's own face has its own.
    Rectangle {
        visible: (island.app.timers.capsule?.dot ?? false) && island.app.activityMode() !== "timer"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: T.liveBadgeInset
        anchors.rightMargin: island.app.shapeEars / 2 + T.liveBadgeInset
        width: T.liveBadge - 2
        height: width
        radius: width / 2
        color: T.textPrimary
    }
}
