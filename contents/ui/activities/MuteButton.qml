import QtQuick
import QtQuick.Controls as QQC2

// System-wide (default sink) mute toggle. State comes from the sink, never kept here.
MouseArea {
    id: button

    property var app: null
    property bool large: false
    property bool playing: false
    readonly property bool muted: app && app.systemMuted
    readonly property color ink: muted ? "#8d8f99" : "#BFC2CC"

    enabled: app && app.systemAudioAvailable
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    Accessible.role: Accessible.Button
    Accessible.name: muted ? i18n("Unmute system audio") : i18n("Mute system audio")
    Accessible.onPressAction: clicked(null)
    onClicked: app.toggleSystemMute()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: button.pressed ? "#25252b" : button.containsMouse && button.large ? "#1b1b21" : "transparent"
    }

    AudioBars {
        id: bars

        anchors.centerIn: parent
        width: button.large ? 20 : 16
        height: button.large ? 16 : 12
        barWidth: button.large ? 2.5 : 1.5
        barColor: button.ink
        playing: button.playing
        clock: button.app ? button.app.decorClock : null
        opacity: button.enabled ? 1 : 0.5
    }

    // Diagonal slash over the bars, with a dark halo so it stays readable on them.
    Item {
        visible: button.muted
        anchors.centerIn: bars
        width: Math.hypot(bars.width, bars.height)
        height: 4
        rotation: Math.atan2(bars.height, bars.width) * 180 / Math.PI

        Rectangle { anchors.fill: parent; radius: 2; color: "#050507" }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: button.large ? 2 : 1.5
            radius: 1
            color: "#e9e9ef"
        }
    }

    QQC2.ToolTip.visible: containsMouse && large
    QQC2.ToolTip.delay: 350
    QQC2.ToolTip.text: muted ? i18n("Unmute system audio") : i18n("Mute system audio")
}
