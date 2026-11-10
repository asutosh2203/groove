import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "Tokens.js" as T

MouseArea {
    id: kdeTile

    required property var app
    readonly property var devices: app.kdeConnectDevices(rowLimit)
    readonly property int totalDevices: app.kdeConnectDevices(0).length
    readonly property int reachableDevices: app.kdeConnectReachableCount()
    readonly property bool hasDevices: totalDevices > 0
    readonly property bool iconOnly: width < 92 || height < 54
    readonly property bool compact: width < 160 || height < 110
    readonly property bool detailed: width >= 220 && height >= 145
    readonly property int rowLimit: compact ? 1 : Math.max(1, Math.floor((height - 54) / 44))
    readonly property int visibleDeviceCount: devices ? devices.length : 0

    function deviceText(device, key, fallbackValue) {
        if (!device || device[key] === undefined || device[key] === null)
            return fallbackValue;

        return app.cleanText(device[key]);
    }

    anchors.fill: parent
    hoverEnabled: true
    enabled: !app.controlEditMode
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: "KDE Connect"
    Accessible.description: app.kdeConnectSummary()
    Accessible.onPressAction: app.launchKdeConnectSettings()
    Keys.onSpacePressed: app.launchKdeConnectSettings()
    Keys.onReturnPressed: app.launchKdeConnectSettings()
    Keys.onEnterPressed: app.launchKdeConnectSettings()
    onPressed: kdeTile.forceActiveFocus()
    onClicked: app.launchKdeConnectSettings()

    Rectangle {
        anchors.fill: parent
        radius: Math.min(T.radiusCard, Math.min(width, height) / 2)
        color: kdeTile.pressed ? T.cardPressed : kdeTile.containsMouse ? T.cardHover : "transparent"
        border.color: kdeTile.activeFocus ? T.focusRing : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        visible: !kdeTile.iconOnly
        anchors.fill: parent
        anchors.margins: 10
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Kirigami.Icon {
                Layout.preferredWidth: 19
                Layout.preferredHeight: 19
                source: T.symbolic("kdeconnect")
                isMask: true
                color: kdeTile.reachableDevices > 0 ? T.iconActive : T.iconIdle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: i18n("KDE Connect")
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: kdeTile.reachableDevices > 0 ? i18np("%1 reachable device", "%1 reachable devices", kdeTile.reachableDevices) : app.kdeConnectSummary()
                    color: T.textSecondary
                    font.pixelSize: T.fontCaption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            IslandButton {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "view-refresh"
                tooltipText: i18n("Refresh devices")
                compact: true
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: app.refreshKdeConnectDevices()
            }

            IslandButton {
                visible: !kdeTile.compact
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "settings"
                tooltipText: i18n("Open KDE Connect")
                compact: true
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: app.launchKdeConnectSettings()
            }
        }

        Repeater {
            model: kdeTile.devices

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: kdeTile.detailed ? 42 : 30
                radius: T.radiusInner
                color: T.row
                border.color: T.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 7

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: modelData && modelData.reachable ? T.fill : modelData && modelData.paired ? T.textCaption : T.textTertiary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -1

                        PlasmaLabel {
                            Layout.fillWidth: true
                            text: kdeTile.deviceText(modelData, "name", i18n("Device"))
                            color: T.textPrimary
                            font.pixelSize: T.fontBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        PlasmaLabel {
                            visible: kdeTile.detailed
                            Layout.fillWidth: true
                            text: kdeTile.deviceText(modelData, "status", i18n("available"))
                            color: T.textSecondary
                            font.pixelSize: T.fontCaption
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    Row {
                        visible: kdeTile.deviceText(modelData, "id", "").length > 0 && kdeTile.detailed
                        spacing: 5

                        IslandButton {
                            width: 22
                            height: 22
                            iconName: "dialog-information"
                            tooltipText: i18n("Ping device")
                            compact: true
                            flat: true
                            focusColor: T.focusRing
                            flatHoverColor: T.raised
                            flatPressedColor: T.chip
                            onClicked: app.runKdeConnectDeviceAction(kdeTile.deviceText(modelData, "id", ""), "ping")
                        }

                        IslandButton {
                            width: 22
                            height: 22
                            iconName: "notifications"
                            tooltipText: i18n("Ring device")
                            compact: true
                            flat: true
                            focusColor: T.focusRing
                            flatHoverColor: T.raised
                            flatPressedColor: T.chip
                            onClicked: app.runKdeConnectDeviceAction(kdeTile.deviceText(modelData, "id", ""), "ring")
                        }

                        IslandButton {
                            visible: kdeTile.width >= 285
                            width: 22
                            height: 22
                            iconName: "folder"
                            tooltipText: i18n("Mount files")
                            compact: true
                            flat: true
                            focusColor: T.focusRing
                            flatHoverColor: T.raised
                            flatPressedColor: T.chip
                            onClicked: app.runKdeConnectDeviceAction(kdeTile.deviceText(modelData, "id", ""), "mount")
                        }
                    }
                }
            }
        }

        PlasmaLabel {
            visible: !kdeTile.hasDevices
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: i18n("No devices found")
            color: T.textTertiary
            font.pixelSize: T.fontCaption
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        PlasmaLabel {
            visible: kdeTile.hasDevices && kdeTile.totalDevices > kdeTile.visibleDeviceCount
            Layout.fillWidth: true
            text: i18n("+%1 more", kdeTile.totalDevices - kdeTile.visibleDeviceCount)
            color: T.textTertiary
            font.pixelSize: T.fontCaption
            horizontalAlignment: Text.AlignRight
        }
    }

    Kirigami.Icon {
        visible: kdeTile.iconOnly
        anchors.centerIn: parent
        width: Math.max(20, Math.min(36, parent.width - 14, parent.height - 14))
        height: width
        source: T.symbolic("kdeconnect")
        isMask: true
        color: kdeTile.reachableDevices > 0 ? T.iconActive : T.iconIdle
    }

    Rectangle {
        visible: kdeTile.iconOnly && kdeTile.hasDevices
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        width: 8
        height: 8
        radius: 4
        color: kdeTile.reachableDevices > 0 ? T.fill : T.textTertiary
    }

    QQC2.ToolTip.visible: kdeTile.containsMouse || kdeTile.activeFocus
    QQC2.ToolTip.text: kdeTile.hasDevices ? app.kdeConnectSummary() : i18n("No reachable KDE Connect devices")
    QQC2.ToolTip.delay: 350
}
