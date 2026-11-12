import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: notificationCompact

    property var app: null
    readonly property int row: app ? app.notifications.latestRow() : -1
    readonly property int unreadCount: app ? app.notifications.unreadCount : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 2
        spacing: 5

        PlasmaLabel {
            Layout.fillWidth: true
            text: notificationCompact.row >= 0 ? notificationCompact.app.notifications.title(notificationCompact.row) : i18n("Notification")
            color: "#f2f2f7"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Item {
            Layout.preferredWidth: Math.max(18, unreadLabel.implicitWidth + 10)
            Layout.preferredHeight: 18

            Rectangle {
                id: unreadPulse

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: height / 2
                color: "#ff9f0a"
                opacity: 0.16

                // A few pulses draw the eye to new unread items, then it stays still: an endless loop kept the
                // whole panel redrawing every frame for as long as something was unread (perf, D-34).
                SequentialAnimation {
                    id: pulse

                    loops: 3
                    NumberAnimation { target: unreadPulse; property: "scale"; to: 1.12; duration: 520; easing.type: Easing.InOutSine }
                    NumberAnimation { target: unreadPulse; property: "scale"; to: 1; duration: 520; easing.type: Easing.InOutSine }
                }

                Connections {
                    target: notificationCompact

                    function onUnreadCountChanged() {
                        if (notificationCompact.unreadCount > 0)
                            pulse.restart();
                        else {
                            pulse.stop();
                            unreadPulse.scale = 1;
                        }
                    }
                }

                Component.onCompleted: {
                    if (notificationCompact.unreadCount > 0)
                        pulse.start();
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#2a1c0c"
                border.color: "#73480d"
                border.width: 1
            }

            PlasmaLabel {
                id: unreadLabel

                anchors.centerIn: parent
                text: notificationCompact.unreadCount > 0 ? String(notificationCompact.unreadCount) : "!"
                color: "#ffd7a1"
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
    }
}
