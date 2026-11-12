import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "Tokens.js" as T
import "../logic/Utils.js" as Utils

MouseArea {
    id: simpleTile

    required property var app
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    // Only used for the single semantic state (e.g. low battery).
    property bool critical: false
    property real progress: -1
    property string detailText: ""
    property string footerText: ""
    property string actionIconName: ""
    property bool available: true
    readonly property bool iconOnly: width < 92 || height < 54
    readonly property bool detailed: !iconOnly && width >= 142 && height >= 88
    readonly property bool tiny: width < 72 || height < 72
    readonly property bool hasAction: actionIconName.length > 0
    readonly property bool showProgressFill: progress >= 0 && !iconOnly && detailed
    readonly property real contentMargin: iconOnly ? 6 : 8
    readonly property real safeProgress: Utils.clampNumber(progress, 0, 100)
    readonly property color glyphColor: critical ? T.critical : active ? T.iconActive : T.iconIdle
    readonly property color barColor: critical ? T.critical : T.fill

    signal triggered()
    signal actionTriggered()

    anchors.fill: parent
    hoverEnabled: true
    enabled: !app.controlEditMode
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: simpleTile.title.length > 0 ? simpleTile.title : simpleTile.iconName
    Accessible.description: simpleTile.subtitle + (simpleTile.detailText.length > 0 ? ". " + simpleTile.detailText : "")
    Accessible.onPressAction: simpleTile.triggered()
    Keys.onSpacePressed: simpleTile.triggered()
    Keys.onReturnPressed: simpleTile.triggered()
    Keys.onEnterPressed: simpleTile.triggered()
    onPressed: simpleTile.forceActiveFocus()
    onClicked: simpleTile.triggered()

    // The module card already provides the surface and border; the tile only
    // adds a hover/press overlay and the focus ring.
    Rectangle {
        anchors.fill: parent
        radius: Math.min(T.radiusCard, Math.min(width, height) / 2)
        color: !simpleTile.available ? "transparent" : simpleTile.pressed ? T.cardPressed : simpleTile.containsMouse ? T.cardHover : "transparent"
        border.color: simpleTile.activeFocus ? T.focusRing : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: simpleTile.contentMargin
        anchors.rightMargin: simpleTile.detailed && simpleTile.hasAction ? 40 : simpleTile.contentMargin
        spacing: simpleTile.iconOnly ? 0 : 10

        Rectangle {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Math.max(18, Math.min(simpleTile.detailed ? 34 : 32, simpleTile.width - simpleTile.contentMargin * 2, simpleTile.height - simpleTile.contentMargin * 2))
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: simpleTile.active || simpleTile.critical ? T.chip : T.raised
            opacity: simpleTile.available ? 1 : T.disabledOpacity

            Behavior on color { ColorAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.56)
                height: width
                source: T.symbolic(simpleTile.iconName)
                isMask: true
                color: simpleTile.glyphColor
            }
        }

        ColumnLayout {
            visible: !simpleTile.iconOnly
            Layout.fillWidth: true
            spacing: simpleTile.detailed ? 4 : 1

            PlasmaLabel {
                Layout.fillWidth: true
                text: simpleTile.title
                color: T.textPrimary
                font.pixelSize: simpleTile.tiny ? T.fontCaption : T.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: simpleTile.subtitle
                color: T.textSecondary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                visible: simpleTile.detailed && simpleTile.detailText.length > 0
                Layout.fillWidth: true
                text: simpleTile.detailText
                color: T.textCaption
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                visible: simpleTile.showProgressFill
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 2
                color: T.track

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * simpleTile.safeProgress / 100
                    radius: parent.radius
                    color: simpleTile.barColor

                    Behavior on width { NumberAnimation { duration: T.motionFast; easing.type: Easing.OutCubic } }
                }
            }

            PlasmaLabel {
                visible: simpleTile.detailed && simpleTile.footerText.length > 0
                Layout.fillWidth: true
                text: simpleTile.footerText
                color: T.textTertiary
                font.pixelSize: T.fontCaption
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    IslandButton {
        visible: simpleTile.detailed && simpleTile.hasAction
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        width: 26
        height: 26
        compact: true
        flat: true
        focusColor: T.focusRing
        flatHoverColor: T.raised
        flatPressedColor: T.chip
        iconName: simpleTile.actionIconName
        tooltipText: typeof i18n === "function" ? i18n("Open settings") : "Open settings"
        onClicked: simpleTile.actionTriggered()
    }

    QQC2.ToolTip.visible: (simpleTile.containsMouse || simpleTile.activeFocus) && (simpleTile.detailText.length > 0 || simpleTile.footerText.length > 0)
    QQC2.ToolTip.text: simpleTile.title + (simpleTile.subtitle.length > 0 ? " - " + simpleTile.subtitle : "") + (simpleTile.detailText.length > 0 ? "\n" + simpleTile.detailText : "")
    QQC2.ToolTip.delay: 350
}
