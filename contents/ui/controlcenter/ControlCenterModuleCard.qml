import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import ".."
import "Tokens.js" as T

Rectangle {
    id: moduleCard

    required property var app
    required property Item hostItem
    required property var notificationsSource
    required property var batterySource
    required property var connectionsSource
    required property var screenBrightnessSource
    required property var keyboardBrightnessSource
    required property var powerProfilesSource
    property string moduleId: ""
    property int moduleIndex: -1
    property int moduleWidthUnits: 1
    property int moduleHeightUnits: 1
    property real gridUnitSize: 64
    property real gridGap: 8
    property bool fromPalette: false

    radius: T.radiusCard
    color: T.card
    border.color: app.layoutService.editMode ? T.borderStrong : T.border
    border.width: 1
    clip: true
    opacity: app.layoutService.dragActive && app.layoutService.dragSource === moduleCard ? 0 : 1
    z: 2
    scale: 1

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    Behavior on x { enabled: app.layoutService.editMode; NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: app.layoutService.editMode; NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }

    Loader {
        anchors.fill: parent
        anchors.margins: app.layoutService.editMode ? Math.min(8, Math.max(4, Math.min(moduleCard.width, moduleCard.height) * 0.1)) : 0
        sourceComponent: {
            if (moduleCard.moduleId === "userPower")
                return userPowerModule;
            if (moduleCard.moduleId === "volume")
                return volumeModule;
            if (moduleCard.moduleId === "brightness")
                return brightnessModule;
            if (moduleCard.moduleId === "wifi")
                return wifiModule;
            if (moduleCard.moduleId === "wifiDevices")
                return wifiDevicesModule;
            if (moduleCard.moduleId === "bluetooth")
                return bluetoothModule;
            if (moduleCard.moduleId === "bluetoothDiscovery")
                return bluetoothDiscoveryModule;
            if (moduleCard.moduleId === "notifications")
                return notificationsModule;
            if (moduleCard.moduleId === "batteryStatus")
                return batteryStatusModule;
            if (moduleCard.moduleId === "batteryPercent")
                return batteryPercentModule;
            if (moduleCard.moduleId === "powerMode")
                return powerModeModule;
            if (moduleCard.moduleId === "appearanceMode")
                return appearanceModeModule;
            if (moduleCard.moduleId === "theme")
                return themeModule;
            if (moduleCard.moduleId === "media")
                return mediaModule;
            if (moduleCard.moduleId === "kdeConnect")
                return kdeConnectModule;
            if (moduleCard.moduleId === "settings")
                return settingsModule;
            return emptyModule;
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: app.layoutService.editMode
        color: "transparent"
        border.color: T.borderStrong
        border.width: 1
        radius: parent.radius
    }

    MouseArea {
        id: dragArea
        visible: app.layoutService.editMode
        anchors.fill: parent
        anchors.margins: 2
        hoverEnabled: true
        drag.threshold: 8
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        onPressed: (mouse) => {
            mouse.accepted = true;
            const local = dragArea.mapToItem(moduleCard, mouse.x, mouse.y);
            const pitch = Math.max(1, moduleCard.gridUnitSize + moduleCard.gridGap);
            app.layoutService.dragOffsetCol = Math.max(0, Math.min(moduleCard.moduleWidthUnits - 1, Math.floor(local.x / pitch)));
            app.layoutService.dragOffsetRow = Math.max(0, Math.min(moduleCard.moduleHeightUnits - 1, Math.floor(local.y / pitch)));
            app.layoutService.beginDrag(moduleCard, dragArea, mouse, 54);
        }
        onPositionChanged: (mouse) => {
            mouse.accepted = true;
            app.layoutService.updateDrag(dragArea, mouse);
        }
        onReleased: (mouse) => {
            mouse.accepted = true;
            app.layoutService.endDrag(dragArea, mouse, true);
        }
        onCanceled: app.layoutService.endDrag(null, null, false)
    }

    Rectangle {
        visible: app.layoutService.editMode
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 7
        radius: 9
        color: T.raised
        border.color: T.borderStrong
        border.width: 1
        width: moduleLabel.implicitWidth + 16
        height: 22

        PlasmaLabel {
            id: moduleLabel
            anchors.centerIn: parent
            text: app.layoutService.moduleInfo(moduleCard.moduleId).name
            color: T.textCaption
            font.pixelSize: T.fontCaption
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: resizeHandle
        property real startPointerX: 0
        property real startPointerY: 0
        property int startW: 1
        property int startH: 1

        visible: app.layoutService.editMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.min(34, Math.max(24, Math.min(moduleCard.width, moduleCard.height) * 0.55))
        height: width
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true
        onPressed: (mouse) => {
            if (!moduleCard.hostItem || !resizeHandle.mapToItem) {
                mouse.accepted = false;
                return;
            }

            mouse.accepted = true;
            const p = resizeHandle.mapToItem(moduleCard.hostItem, mouse.x, mouse.y);
            startPointerX = p.x;
            startPointerY = p.y;
            startW = moduleCard.moduleWidthUnits;
            startH = moduleCard.moduleHeightUnits;
            app.layoutService.beginResize(moduleCard);
        }
        onPositionChanged: (mouse) => {
            if (!pressed || !app.layoutService.resizeActive || !moduleCard.hostItem || !resizeHandle.mapToItem)
                return;

            mouse.accepted = true;
            const p = resizeHandle.mapToItem(moduleCard.hostItem, mouse.x, mouse.y);
            const step = Math.max(1, moduleCard.gridUnitSize + moduleCard.gridGap);
            const newW = startW + Math.round((p.x - startPointerX) / step);
            const newH = startH + Math.round((p.y - startPointerY) / step);
            app.layoutService.updateResize(moduleCard, newW, newH);
        }
        onReleased: (mouse) => {
            mouse.accepted = true;
            app.layoutService.endResize(moduleCard, true);
        }
        onCanceled: app.layoutService.endResize(moduleCard, false)

        Canvas {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 24
            height: 24
            opacity: resizeHandle.containsMouse ? 1 : 0.62
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = T.textCaption;
                ctx.lineWidth = 2;
                for (let i = 0; i < 3; ++i) {
                    ctx.beginPath();
                    ctx.moveTo(width - 5 - i * 6, height - 2);
                    ctx.lineTo(width - 2, height - 5 - i * 6);
                    ctx.stroke();
                }
            }
        }
    }

    Component { id: userPowerModule; UserPowerTile { app: moduleCard.app } }
    Component {
        id: volumeModule
        ControlSliderTile {
            app: moduleCard.app
            title: i18n("Volume")
            iconName: {
                const sink = app.system.defaultSink();
                if (!sink || app.system.volumePercent() <= 0 || sink.muted)
                    return "audio-volume-muted";
                return app.system.volumePercent() < 45 ? "audio-volume-low" : "audio-volume-high";
            }
            valueText: {
                const sink = app.system.defaultSink();
                return sink && sink.muted ? i18n("Muted") : app.system.volumePercent() + "%";
            }
            value: app.system.volumePercent()
            toValue: 150
            sliderEnabled: app.system.defaultSink() !== null
            actionIconName: {
                const sink = app.system.defaultSink();
                return sink && sink.muted ? "audio-volume-high" : "audio-volume-muted";
            }
            actionTooltip: {
                const sink = app.system.defaultSink();
                return sink && sink.muted ? i18n("Unmute") : i18n("Mute");
            }
            secondaryActionIconName: "settings"
            secondaryActionTooltip: i18n("Audio settings")
            onActionTriggered: app.system.toggleMute()
            onSecondaryActionTriggered: app.launcher.launchPavucontrol()
            onMoved: (value) => app.system.setVolumePercent(value)
        }
    }
    Component {
        id: brightnessModule
        ControlSliderTile {
            app: moduleCard.app
            title: i18n("Brightness")
            iconName: value <= 1 ? "brightness-low" : value < 55 ? "brightness-medium" : "brightness-high"
            valueText: screenBrightnessSource.isBrightnessAvailable ? app.system.displayedScreenPercent() + "%" : "--"
            value: app.system.displayedScreenPercent()
            sliderEnabled: screenBrightnessSource.isBrightnessAvailable
            actionIconName: "video-display"
            actionTooltip: i18n("Display settings")
            secondaryActionIconName: keyboardBrightnessSource.isBrightnessAvailable ? "input-keyboard" : ""
            secondaryActionTooltip: i18n("Toggle keyboard brightness")
            onActionTriggered: app.launcher.launchDisplaySettings()
            onSecondaryActionTriggered: app.system.setKeyboardPercent(app.system.keyboardPercent() <= 20 ? 100 : 0)
            onMoved: (value) => app.system.setScreenPercent(value)
        }
    }
    Component {
        id: wifiModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: connectionsSource.wirelessEnabled ? "network-wireless-on" : "network-wireless-off"
            title: i18n("Wi-Fi")
            subtitle: app.connectivity.wifiPrimaryNetwork()
            active: connectionsSource.wirelessEnabled
            available: connectionsSource.wirelessHwEnabled
            progress: app.connectivity.wifiSignalPercent()
            detailText: app.wifiTitle()
            footerText: connectionsSource.wirelessHwEnabled ? (connectionsSource.wirelessEnabled ? i18n("Click to turn off") : i18n("Click to turn on")) : i18n("No adapter")
            actionIconName: "settings"
            onActionTriggered: app.launcher.launchNetworkSettings()
            onTriggered: connectionsSource.wirelessHwEnabled ? app.connectivity.toggleWifi() : app.launcher.launchNetworkSettings()
        }
    }
    Component { id: wifiDevicesModule; NetworkListTile { app: moduleCard.app } }
    Component { id: mediaModule; ActivitySummaryTile { app: moduleCard.app; notificationsSource: moduleCard.notificationsSource; mediaOnly: true; radius: moduleCard.radius; border.width: 1; border.color: moduleCard.app.layoutService.editMode ? T.borderStrong : T.border } }
    Component { id: notificationsModule; NotificationsTile { app: moduleCard.app; notificationsSource: moduleCard.notificationsSource } }
    Component {
        id: bluetoothModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "preferences-system-bluetooth"
            title: i18n("Bluetooth")
            subtitle: app.bluetoothSummary()
            active: app.connectivity.bluetoothPowered && app.connectivity.bluetoothAvailable
            available: app.connectivity.bluetoothAvailable
            detailText: app.bluetoothDetail()
            footerText: app.connectivity.bluetoothAvailable ? (app.connectivity.bluetoothPowered ? i18n("Click to turn off") : i18n("Click to turn on")) : i18n("Open settings")
            actionIconName: "settings"
            onActionTriggered: app.launcher.launchBluetoothSettings()
            onTriggered: app.connectivity.bluetoothAvailable ? app.connectivity.toggleBluetoothPower() : app.launcher.launchBluetoothSettings()
        }
    }
    Component {
        id: bluetoothDiscoveryModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "preferences-system-bluetooth"
            title: app.connectivity.bluetoothDeviceCount() > 0 ? i18n("Connected") : i18n("Discover")
            subtitle: app.connectivity.bluetoothAvailable ? app.bluetoothSummary() : i18n("No adapter")
            active: app.connectivity.bluetoothPowered && app.connectivity.bluetoothAvailable
            available: app.connectivity.bluetoothAvailable
            detailText: app.bluetoothDetail()
            footerText: app.connectivity.bluetoothAvailable ? i18n("Open Bluetooth") : i18n("Open settings")
            onTriggered: app.launcher.launchBluetoothDiscovery()
        }
    }
    Component {
        id: batteryStatusModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: batterySource.pluggedIn ? "battery-charging" : "battery"
            title: batterySource.hasInternalBatteries ? (batterySource.pluggedIn ? i18n("Charging") : i18n("Battery")) : i18n("Power")
            subtitle: batterySource.hasInternalBatteries ? app.batteryText() : i18n("Desktop")
            active: batterySource.pluggedIn
            critical: batterySource.percent <= 20 && batterySource.hasInternalBatteries
            progress: batterySource.hasInternalBatteries ? batterySource.percent : 100
            detailText: app.batteryText()
            footerText: batterySource.hasInternalBatteries ? (batterySource.pluggedIn ? i18n("Plugged in") : i18n("Discharging")) : i18n("AC power")
            actionIconName: "settings"
            onActionTriggered: app.launcher.launchPowerSettings()
        }
    }
    Component {
        id: batteryPercentModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: batterySource.pluggedIn ? "battery-charging" : "battery"
            title: app.batteryText()
            subtitle: batterySource.hasInternalBatteries ? (batterySource.pluggedIn ? i18n("Charging") : i18n("Remaining")) : i18n("Power")
            active: batterySource.pluggedIn
            critical: batterySource.percent <= 20 && batterySource.hasInternalBatteries
            progress: batterySource.hasInternalBatteries ? batterySource.percent : 100
            detailText: batterySource.pluggedIn ? i18n("Charging") : i18n("Power")
            actionIconName: "settings"
            onActionTriggered: app.launcher.launchPowerSettings()
        }
    }
    Component {
        id: powerModeModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: app.system.profileIcon()
            title: app.powerProfileTitle()
            subtitle: i18n("Power mode")
            active: true
            detailText: powerProfilesSource.profiles && powerProfilesSource.profiles.length > 1 ? i18n("Click to cycle") : i18n("Current profile")
            footerText: app.powerProfileTitle()
            actionIconName: "settings"
            onActionTriggered: app.launcher.launchPowerSettings()
            onTriggered: app.system.cycleProfile()
        }
    }
    Component {
        id: appearanceModeModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "preferences-desktop-theme"
            title: Brightness.DarkModeControl.darkMode ? i18n("Dark") : i18n("Light")
            subtitle: i18n("Appearance")
            active: Brightness.DarkModeControl.darkMode
            detailText: i18n("Desktop color scheme")
            footerText: i18n("Click to switch")
            onTriggered: app.system.toggleAppearanceMode()
        }
    }
    Component {
        id: themeModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "preferences-desktop-theme-global"
            title: i18n("Theme")
            subtitle: i18n("Global themes")
            active: false
            detailText: i18n("Open KDE themes")
            onTriggered: app.launcher.launchAppearanceSettings()
        }
    }
    Component {
        id: kdeConnectModule
        KdeConnectTile {
            app: moduleCard.app
        }
    }
    Component {
        id: settingsModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "systemsettings"
            title: i18n("Settings")
            subtitle: i18n("System")
            active: false
            detailText: i18n("Open System Settings")
            onTriggered: app.launcher.launchSystemSettings()
        }
    }
    Component {
        id: emptyModule
        SimpleModuleTile {
            app: moduleCard.app
            iconName: "unknown"
            title: moduleCard.moduleId
            subtitle: i18n("Unknown")
            active: false
        }
    }
}
