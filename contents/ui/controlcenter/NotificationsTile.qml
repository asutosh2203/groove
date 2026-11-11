import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import ".."
import "../activities" as Activities
import "Tokens.js" as T

Item {
    id: notificationsContent

    required property var app
    required property var notificationsSource
    readonly property int notificationTotal: app.notificationCount()
    readonly property bool iconOnly: width < 100 || height < 62
    readonly property bool compact: width < 170 || height < 118
    readonly property bool detailed: width >= 230 && height >= 150
    readonly property int rowHeight: detailed ? 56 : 30
    // One shared clock for every row's relative timestamp (refreshed once a minute).
    property real nowMs: Date.now()
    readonly property int rowLimit: compact ? 1 : Math.max(1, Math.floor((height - 56) / rowHeight))
    readonly property int overflowCount: app.notificationOverflowCount(rowLimit)

    // "now", "5m ago", "3h ago", "Yesterday", then a localised date. Empty when the creation time is unknown.
    function ageText(row, now) {
        const created = app.notificationCreatedMs(row);
        if (created <= 0)
            return "";
        const minutes = Math.floor(Math.max(0, now - created) / 60000);
        if (minutes < 1)
            return i18n("now");
        if (minutes < 60)
            return i18n("%1m ago", minutes);
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return i18n("%1h ago", hours);
        const date = new Date(created);
        const today = new Date(now);
        const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
        if (date.getFullYear() === yesterday.getFullYear() && date.getMonth() === yesterday.getMonth() && date.getDate() === yesterday.getDate())
            return i18n("Yesterday");
        return Qt.formatDate(date, date.getFullYear() === today.getFullYear() ? "MMM d" : "MMM d, yyyy");
    }

    Timer {
        interval: 60000
        repeat: true
        running: notificationsContent.visible && notificationsContent.notificationTotal > 0
        onTriggered: notificationsContent.nowMs = Date.now()
    }

    function closeRow(row) {
        if (row < 0 || row >= notificationsSource.count)
            return;

        if (!app.rowValue(row, NotificationManager.Notifications.ClosableRole, true))
            return;

        notificationsSource.close(notificationsSource.index(row, 0));
    }

    anchors.fill: parent
    activeFocusOnTab: false
    Accessible.role: Accessible.Grouping
    Accessible.name: i18n("Notifications")

    ColumnLayout {
        visible: !notificationsContent.iconOnly
        anchors.fill: parent
        anchors.margins: 10
        anchors.bottomMargin: 17
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Kirigami.Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: notificationsContent.notificationTotal > 0 ? "notifications" : "notifications-disabled"
                isMask: true
                color: notificationsContent.notificationTotal > 0 ? T.iconActive : T.iconIdle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: i18n("Notifications")
                    color: T.textPrimary
                    font.pixelSize: T.fontBody + 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: app.notificationStatusText()
                    color: T.textSecondary
                    font.pixelSize: T.fontCaption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            IslandButton {
                visible: !notificationsContent.compact
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "edit-clear-all"
                tooltipText: i18n("Clear notifications")
                compact: true
                enabled: notificationsContent.notificationTotal > 0
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: app.clearNotifications()
            }

            IslandButton {
                visible: !notificationsContent.compact
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "settings"
                tooltipText: i18n("Notification settings")
                compact: true
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: app.launchNotificationSettings()
            }
        }

        // Scrolling viewport: clipped at its own edges, which sit inside the card's rounded corners.
        Flickable {
            id: listView

            visible: notificationsContent.notificationTotal > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: listColumn.height
            boundsBehavior: Flickable.StopAtBounds
            bottomMargin: 6
            // Clip the scrolling content to a rounded shape, not just a rectangle.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSpreadAtMax: 1
                maskSpreadAtMin: 1
                maskThresholdMin: 0.5

                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: listView.width
                        height: listView.height
                        radius: 12
                        color: "#ffffff"
                    }
                }
            }
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: QQC2.ScrollBar.AsNeeded
            }

            Column {
                id: listColumn

                // Keep rows clear of the scrollbar when it is shown.
                width: listView.width - (listView.contentHeight > listView.height ? 10 : 0)
                spacing: 7

                Repeater {
                    model: app.notificationRows(notificationsContent.compact ? notificationsContent.rowLimit : 0)

                    delegate: MouseArea {
                        id: rowArea

                        width: listColumn.width
                        height: notificationsContent.rowHeight
                        hoverEnabled: true
                        enabled: !app.controlEditMode
                        activeFocusOnTab: enabled
                        Accessible.role: Accessible.Button
                        Accessible.name: app.notificationTitle(modelData)
                        Accessible.description: app.notificationAppName(modelData)
                        Accessible.onPressAction: app.openNotification(modelData)
                        Keys.onSpacePressed: app.openNotification(modelData)
                        Keys.onReturnPressed: app.openNotification(modelData)
                        Keys.onEnterPressed: app.openNotification(modelData)
                        onPressed: rowArea.forceActiveFocus()
                        onClicked: app.openNotification(modelData)

                        Rectangle {
                            anchors.fill: parent
                            radius: T.radiusInner
                            color: rowArea.pressed ? T.cardPressed : rowArea.containsMouse ? T.rowHover : T.row
                            border.color: rowArea.activeFocus ? T.focusRing : T.border
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: notificationsContent.detailed ? 34 : 22
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: Math.min(10, width / 2)
                                color: Qt.rgba(1, 1, 1, 0.05)

                                Activities.NotificationVisual {
                                    anchors.fill: parent
                                    source: notificationsContent.detailed && app.notificationImagesEnabled ? app.notificationMainImage(modelData) : app.notificationAppIcon(modelData)
                                    fallbackSource: app.notificationMainIcon(modelData)
                                    fallbackColor: T.textCaption
                                    cornerRadius: Math.min(10, width / 2)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: notificationsContent.detailed ? 1 : -1

                                // Source on the left, relative time on the right (detailed rows).
                                RowLayout {
                                    visible: notificationsContent.detailed
                                    Layout.fillWidth: true
                                    spacing: 6

                                    PlasmaLabel {
                                        Layout.fillWidth: true
                                        text: app.notificationAppName(modelData)
                                        color: T.textTertiary
                                        font.pixelSize: T.fontCaption
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    PlasmaLabel {
                                        visible: text.length > 0
                                        text: notificationsContent.ageText(modelData, notificationsContent.nowMs)
                                        color: T.textTertiary
                                        font.pixelSize: T.fontCaption
                                        font.features: { "tnum": 1 }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    PlasmaLabel {
                                        Layout.fillWidth: true
                                        text: app.notificationTitle(modelData)
                                        color: T.textPrimary
                                        font.pixelSize: notificationsContent.detailed ? T.fontBody : T.fontCaption
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Rectangle {
                                        // Only urgent notifications get a coloured marker.
                                        visible: notificationsContent.detailed && app.notificationUrgency(modelData) >= NotificationManager.Notifications.CriticalUrgency
                                        Layout.preferredWidth: 6
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: T.critical
                                    }

                                    // Compact rows have no source line, so the time sits beside the title.
                                    PlasmaLabel {
                                        visible: !notificationsContent.detailed && text.length > 0
                                        text: notificationsContent.ageText(modelData, notificationsContent.nowMs)
                                        color: T.textTertiary
                                        font.pixelSize: T.fontCaption
                                        font.features: { "tnum": 1 }
                                    }
                                }

                                PlasmaLabel {
                                    visible: !notificationsContent.detailed || text.length > 0
                                    Layout.fillWidth: true
                                    text: notificationsContent.detailed ? app.notificationBody(modelData) : app.notificationAppName(modelData)
                                    textFormat: Text.PlainText
                                    color: T.textSecondary
                                    font.pixelSize: T.fontCaption
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            IslandButton {
                                visible: !notificationsContent.compact
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                iconName: "window-close"
                                tooltipText: i18n("Dismiss")
                                compact: true
                                flat: true
                                focusColor: T.focusRing
                                flatHoverColor: T.raised
                                flatPressedColor: T.chip
                                enabled: app.rowValue(modelData, NotificationManager.Notifications.ClosableRole, true)
                                onClicked: notificationsContent.closeRow(modelData)
                            }
                        }
                    }
                }
            }
        }

        PlasmaLabel {
            visible: notificationsContent.notificationTotal <= 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: i18n("Quiet")
            color: T.textTertiary
            font.pixelSize: T.fontCaption
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        PlasmaLabel {
            visible: notificationsContent.compact && notificationsContent.notificationTotal > 0 && notificationsContent.overflowCount > 0
            Layout.fillWidth: true
            text: i18n("+%1 more", notificationsContent.overflowCount)
            color: T.textTertiary
            font.pixelSize: T.fontCaption
            horizontalAlignment: Text.AlignRight
        }
    }

    Kirigami.Icon {
        visible: notificationsContent.iconOnly
        anchors.centerIn: parent
        width: Math.max(20, Math.min(34, parent.width - 14, parent.height - 14))
        height: width
        source: notificationsContent.notificationTotal > 0 ? "notifications" : "notifications-disabled"
        isMask: true
        color: notificationsContent.notificationTotal > 0 ? T.iconActive : T.iconIdle
    }

    Rectangle {
        visible: notificationsContent.iconOnly && notificationsContent.notificationTotal > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        width: Math.max(16, countLabel.implicitWidth + 8)
        height: 16
        radius: 8
        color: T.fill

        PlasmaLabel {
            id: countLabel

            anchors.centerIn: parent
            text: notificationsContent.notificationTotal
            color: T.iconOnFill
            font.pixelSize: T.fontCaption
            font.weight: Font.DemiBold
        }
    }
}
