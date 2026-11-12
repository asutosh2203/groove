import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import ".."
import "Tokens.js" as T
import "../logic/TextUtils.js" as TextUtils

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
    readonly property int rowHeight: detailed ? 42 : 30
    // Rows that fit under the header; one line is kept for "+N more" when the list overflows.
    readonly property real bodyHeight: height - 20 - 24 - 7
    readonly property int fitRows: Math.max(1, Math.floor((bodyHeight + 7) / (rowHeight + 7)))
    readonly property int rowLimit: totalDevices > fitRows ? Math.max(1, Math.floor((bodyHeight - 17 + 7) / (rowHeight + 7))) : fitRows
    readonly property int visibleDeviceCount: devices ? devices.length : 0

    function deviceText(device, key, fallbackValue) {
        if (!device || device[key] === undefined || device[key] === null)
            return fallbackValue;

        return TextUtils.cleanText(device[key]);
    }

    anchors.fill: parent
    hoverEnabled: true
    enabled: !app.layoutService.editMode
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: "KDE Connect"
    Accessible.description: app.kdeConnectSummary()
    Accessible.onPressAction: app.launcher.launchKdeConnectSettings()
    Keys.onSpacePressed: app.launcher.launchKdeConnectSettings()
    Keys.onReturnPressed: app.launcher.launchKdeConnectSettings()
    Keys.onEnterPressed: app.launcher.launchKdeConnectSettings()
    onPressed: kdeTile.forceActiveFocus()
    onClicked: app.launcher.launchKdeConnectSettings()

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

            PhoneGlyph {
                Layout.preferredWidth: T.iconHeader
                Layout.preferredHeight: T.iconHeader
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
                    text: app.kdeConnectSummary()
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
                onClicked: app.launcher.launchKdeConnectSettings()
            }
        }

        Repeater {
            model: kdeTile.devices

            delegate: Rectangle {
                id: deviceRow

                readonly property bool online: modelData && modelData.reachable
                readonly property string deviceId: kdeTile.deviceText(modelData, "id", "")
                readonly property bool showActions: online && kdeTile.detailed && (rowHover.hovered || ringButton.activeFocus || browseButton.activeFocus)

                Layout.fillWidth: true
                Layout.preferredHeight: kdeTile.rowHeight
                radius: T.radiusInner
                color: T.row
                border.color: T.border
                border.width: 1

                HoverHandler {
                    id: rowHover
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 7

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: deviceRow.online ? T.fill : T.textTertiary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        opacity: deviceRow.online ? 1 : T.disabledOpacity
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
                            text: deviceRow.online ? i18n("Connected") : i18n("Not nearby")
                            color: T.textSecondary
                            font.pixelSize: T.fontCaption
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Faded, not hidden, so keyboard focus can still reach the buttons and reveal them.
                    Row {
                        visible: deviceRow.online && kdeTile.detailed
                        opacity: deviceRow.showActions ? 1 : 0
                        spacing: 5

                        IslandButton {
                            id: ringButton
                            width: 22
                            height: 22
                            iconName: "notifications"
                            tooltipText: i18n("Ring device")
                            compact: true
                            flat: true
                            focusColor: T.focusRing
                            flatHoverColor: T.raised
                            flatPressedColor: T.chip
                            onClicked: app.runKdeConnectDeviceAction(deviceRow.deviceId, "ring")
                        }

                        IslandButton {
                            id: browseButton
                            width: 22
                            height: 22
                            iconName: "folder"
                            tooltipText: i18n("Browse files")
                            compact: true
                            flat: true
                            focusColor: T.focusRing
                            flatHoverColor: T.raised
                            flatPressedColor: T.chip
                            onClicked: app.runKdeConnectDeviceAction(deviceRow.deviceId, "browse")
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: !kdeTile.hasDevices
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Item {
                Layout.fillHeight: true
            }

            PhoneGlyph {
                visible: kdeTile.height >= 140
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.bottomMargin: 6
                color: T.textTertiary
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: i18n("No phone nearby")
                color: T.textCaption
                font.pixelSize: T.fontBody
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                visible: kdeTile.height >= 100
                Layout.fillWidth: true
                text: i18n("Pair one in KDE Connect")
                color: T.textTertiary
                font.pixelSize: T.fontCaption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // Pushes rows up so they sit directly under the header.
        Item {
            visible: kdeTile.hasDevices
            Layout.fillHeight: true
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

    PhoneGlyph {
        visible: kdeTile.iconOnly
        anchors.centerIn: parent
        width: Math.max(20, Math.min(36, parent.width - 14, parent.height - 14))
        height: width
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
