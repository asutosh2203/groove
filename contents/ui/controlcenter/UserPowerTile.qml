import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import ".."
import "Tokens.js" as T

Item {
    id: userPowerContent

    required property var app
    readonly property bool narrow: width < 82
    readonly property bool compact: width < 150 || height < 74
    readonly property bool shortTile: height < 62
    readonly property bool micro: narrow || width < 108
    readonly property real pad: compact ? 7 : 10
    readonly property real avatarSize: Math.max(18, Math.min(compact ? 34 : 38, height - pad * 2, narrow ? width - pad * 2 : width * 0.36))
    readonly property real buttonSize: Math.max(22, Math.min(compact ? 30 : 34, width - pad * 2, height - pad * 2))

    anchors.fill: parent
    Accessible.role: Accessible.Grouping
    Accessible.name: (app.system.systemUsername || i18n("User")) + ". " + (app.system.systemHostname || i18n("KDE Plasma"))

    Rectangle {
        id: profileAvatarFrame
        width: userPowerContent.avatarSize
        height: width
        x: userPowerContent.narrow ? Math.round((parent.width - width) / 2) : userPowerContent.pad
        y: userPowerContent.narrow && !userPowerContent.shortTile ? userPowerContent.pad : Math.round((parent.height - height) / 2)
        radius: width / 2
        color: T.raised
        clip: true

        Image {
            id: profileAvatarImage
            anchors.fill: parent
            source: app.system.faceUrl()
            fillMode: Image.PreserveAspectCrop
            visible: app.system.faceUrl().length > 0 && status === Image.Ready
            layer.enabled: visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSpreadAtMax: 1
                maskSpreadAtMin: 1
                maskThresholdMin: 0.5
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: profileAvatarImage.width
                        height: profileAvatarImage.height
                        radius: Math.min(width, height) / 2
                        color: "#ffffff"
                    }
                }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: "user-identity"
            isMask: true
            color: T.iconIdle
            visible: !profileAvatarImage.visible
        }
    }

    Column {
        id: profileTextColumn
        visible: !userPowerContent.micro || userPowerContent.shortTile && userPowerContent.width >= 92
        x: userPowerContent.shortTile ? profileAvatarFrame.x + profileAvatarFrame.width + 8 : userPowerContent.compact ? userPowerContent.pad : profileAvatarFrame.x + profileAvatarFrame.width + 10
        y: userPowerContent.shortTile ? Math.round((parent.height - height) / 2) : userPowerContent.compact ? profileAvatarFrame.y + profileAvatarFrame.height + 6 : Math.round((parent.height - height) / 2)
        width: userPowerContent.shortTile ? Math.max(1, (powerButton.visible ? powerButton.x - x - 8 : parent.width - x - userPowerContent.pad)) : userPowerContent.compact ? Math.max(1, parent.width - userPowerContent.pad * 2) : Math.max(1, powerButton.x - x - 10)
        spacing: userPowerContent.shortTile ? -1 : 1

        PlasmaLabel {
            width: parent.width
            text: app.system.systemUsername || i18n("User")
            color: T.textPrimary
            font.pixelSize: userPowerContent.shortTile ? T.fontCaption : userPowerContent.compact ? T.fontBody : T.fontTitle
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        PlasmaLabel {
            visible: !userPowerContent.compact || userPowerContent.height >= 34
            width: parent.width
            text: app.system.systemHostname || i18n("KDE Plasma")
            color: T.textSecondary
            font.pixelSize: userPowerContent.shortTile ? T.fontCaption - 1 : T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    IslandButton {
        id: powerButton
        x: userPowerContent.narrow ? Math.round((parent.width - width) / 2) : parent.width - width - userPowerContent.pad
        y: userPowerContent.narrow ? parent.height - height - userPowerContent.pad : userPowerContent.compact ? userPowerContent.pad : Math.round((parent.height - height) / 2)
        width: userPowerContent.buttonSize
        height: width
        visible: !userPowerContent.shortTile && (!userPowerContent.narrow || parent.height >= profileAvatarFrame.height + height + userPowerContent.pad * 3)
        iconName: "system-shutdown"
        compact: true
        restColor: T.raised
        hoverColor: T.chip
        pressedColor: T.cardPressed
        outlineColor: T.border
        focusColor: T.focusRing
        tooltipText: i18n("Power options")
        onClicked: powerMenu.open()

        QQC2.Menu {
            id: powerMenu
            onAboutToShow: app.popupMenuOpen = true
            onAboutToHide: {
                app.popupMenuOpen = false;
                if (app.dialogVisible)
                    app.focusIslandDialog();
            }
            PlasmaMenuItem { text: i18n("Lock"); icon.name: "system-lock-screen"; onTriggered: app.system.runPowerAction("lock") }
            PlasmaMenuItem { text: i18n("Logout"); icon.name: "system-log-out"; onTriggered: app.system.runPowerAction("logout") }
            PlasmaMenuItem { text: i18n("Sleep"); icon.name: "system-suspend"; onTriggered: app.system.runPowerAction("sleep") }
            PlasmaMenuItem { text: i18n("Hibernate"); icon.name: "system-suspend-hibernate"; onTriggered: app.system.runPowerAction("hibernate") }
            QQC2.MenuSeparator {}
            PlasmaMenuItem { text: i18n("Reboot"); icon.name: "system-reboot"; onTriggered: app.system.runPowerAction("reboot") }
            PlasmaMenuItem { text: i18n("Shutdown"); icon.name: "system-shutdown"; onTriggered: app.system.runPowerAction("shutdown") }
        }
    }

    Row {
        visible: !userPowerContent.compact && userPowerContent.width >= 210 && userPowerContent.height >= 116
        x: profileTextColumn.x
        y: parent.height - height - userPowerContent.pad
        spacing: 7

        IslandButton { width: 28; height: 28; iconName: "system-lock-screen"; compact: true; restColor: T.raised; hoverColor: T.chip; pressedColor: T.cardPressed; outlineColor: T.border; focusColor: T.focusRing; tooltipText: i18n("Lock"); onClicked: app.system.runPowerAction("lock") }
        IslandButton { width: 28; height: 28; iconName: "system-suspend"; compact: true; restColor: T.raised; hoverColor: T.chip; pressedColor: T.cardPressed; outlineColor: T.border; focusColor: T.focusRing; tooltipText: i18n("Sleep"); onClicked: app.system.runPowerAction("sleep") }
        IslandButton { width: 28; height: 28; iconName: "preferences-desktop-theme-global"; compact: true; restColor: T.raised; hoverColor: T.chip; pressedColor: T.cardPressed; outlineColor: T.border; focusColor: T.focusRing; tooltipText: i18n("Appearance"); onClicked: app.launcher.launchAppearanceSettings() }
        IslandButton { width: 28; height: 28; iconName: "systemsettings"; compact: true; restColor: T.raised; hoverColor: T.chip; pressedColor: T.cardPressed; outlineColor: T.border; focusColor: T.focusRing; tooltipText: i18n("System Settings"); onClicked: app.launcher.launchSystemSettings() }
    }
}

