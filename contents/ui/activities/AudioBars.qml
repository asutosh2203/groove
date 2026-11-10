import QtQuick

Row {
    id: bars

    property bool playing: false
    property color barColor: "#BFC2CC"
    property real barWidth: 3

    spacing: 2

    Repeater {
        model: [0.45, 0.86, 0.58, 0.74, 0.36]

        Rectangle {
            required property real modelData
            required property int index
            property real level: modelData

            width: bars.barWidth
            height: Math.max(4, bars.height * level)
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: bars.barColor
            opacity: bars.playing ? 0.55 : 0.3

            SequentialAnimation on level {
                running: bars.playing
                loops: Animation.Infinite

                PauseAnimation {
                    duration: index * 55
                }

                NumberAnimation {
                    to: Math.max(0.35, 1 - modelData * 0.25)
                    duration: 400 + index * 40
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: modelData
                    duration: 440 + index * 45
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
