import QtQuick
import ".."
import "../DecorMotion.js" as Motion

Row {
    id: bars

    property bool playing: false
    property color barColor: "#BFC2CC"
    property real barWidth: 3
    // Shared low-rate clock (DecorClock). Without one the bars stay at their resting heights.
    property var clock: null
    property int fps: 8

    DecorClockLease {
        clock: bars.clock
        // Hidden bars (for example a tile layout that doesn't show them) must not keep the clock running.
        active: bars.playing && bars.visible
        fps: bars.fps
    }

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

            // Rest at the original level; while playing, follow the clock (the old per-bar loop, at the clock's rate).
            readonly property real lowLevel: Math.max(0.35, 1 - modelData * 0.25)
            Binding on level {
                when: bars.playing && bars.clock !== null
                value: Motion.cycle(bars.clock ? bars.clock.time : 0, index * 55, 400 + index * 40, 440 + index * 45, modelData, lowLevel)
            }
        }
    }
}
