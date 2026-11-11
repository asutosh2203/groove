import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "Tokens.js" as T

MouseArea {
    id: networkList

    required property var app
    readonly property var networkStatus: app.networkState
    readonly property bool compact: width < 150 || height < 86
    readonly property bool iconOnly: width < 96 || height < 58
    readonly property bool detailed: width >= 190 && height >= 112

    anchors.fill: parent
    hoverEnabled: true
    enabled: !app.controlEditMode
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: networkList.networkStatus.title + " " + networkList.networkStatus.summary
    Accessible.description: networkList.networkStatus.detail
    Accessible.onPressAction: app.launchNetworkSettings()
    Keys.onSpacePressed: app.launchNetworkSettings()
    Keys.onReturnPressed: app.launchNetworkSettings()
    Keys.onEnterPressed: app.launchNetworkSettings()
    onPressed: networkList.forceActiveFocus()
    onClicked: app.launchNetworkSettings()

    Rectangle {
        anchors.fill: parent
        radius: Math.min(T.radiusCard, Math.min(width, height) / 2)
        color: networkList.pressed ? T.cardPressed : networkList.containsMouse ? T.cardHover : "transparent"
        border.color: networkList.activeFocus ? T.focusRing : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        visible: !networkList.iconOnly
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Kirigami.Icon {
                Layout.preferredWidth: T.iconHeader
                Layout.preferredHeight: T.iconHeader
                source: networkList.networkStatus.icon
                isMask: true
                color: networkList.networkStatus.connected ? T.iconActive : T.iconIdle
            }
            PlasmaLabel {
                Layout.fillWidth: true
                text: networkList.networkStatus.title
                textFormat: Text.PlainText
                color: T.textPrimary
                font.pixelSize: T.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaLabel {
                visible: networkList.width >= 156 && networkList.networkStatus.signal >= 0
                text: networkList.networkStatus.signal + "%"
                color: T.textCaption
                font.pixelSize: T.fontCaption
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            IslandButton {
                visible: !networkList.compact
                enabled: networkList.enabled
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "view-refresh"
                tooltipText: typeof i18n === "function" ? i18n("Refresh network status") : "Refresh network status"
                compact: true
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: networkList.app.refreshWifiNetworks()
            }
            IslandButton {
                visible: !networkList.compact && networkList.width >= 230
                enabled: networkList.enabled
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                iconName: "settings"
                tooltipText: typeof i18n === "function" ? i18n("Network settings") : "Network settings"
                compact: true
                flat: true
                focusColor: T.focusRing
                flatHoverColor: T.raised
                flatPressedColor: T.chip
                onClicked: networkList.app.launchNetworkSettings()
            }
        }

        PlasmaLabel {
            Layout.fillWidth: true
            text: networkList.networkStatus.summary
            textFormat: Text.PlainText
            color: T.textPrimary
            font.pixelSize: networkList.compact ? T.fontCaption : T.fontBody + 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        PlasmaLabel {
            visible: networkList.detailed
            Layout.fillWidth: true
            text: networkList.networkStatus.detailLine
            textFormat: Text.PlainText
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Item {
            visible: networkList.detailed
            Layout.fillHeight: true
        }

        RowLayout {
            visible: networkList.detailed
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 4
                color: networkList.networkStatus.connected ? T.fill : T.textTertiary
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: networkList.networkStatus.footer
                color: T.textTertiary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    Kirigami.Icon {
        visible: networkList.iconOnly
        anchors.centerIn: parent
        width: Math.max(20, Math.min(36, parent.width - 14, parent.height - 14))
        height: width
        source: networkList.networkStatus.icon
        isMask: true
        color: networkList.networkStatus.connected ? T.iconActive : T.iconIdle
    }

    QQC2.ToolTip {
        id: networkToolTip

        visible: networkList.containsMouse || networkList.activeFocus
        text: networkList.networkStatus.detail
        delay: 350
        contentItem: PlasmaLabel {
            text: networkToolTip.text
            textFormat: Text.PlainText
            color: networkToolTip.palette.toolTipText
            wrapMode: Text.Wrap
        }
    }
}
