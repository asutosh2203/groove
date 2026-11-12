import QtQuick
import ".."
import "../DecorMotion.js" as Motion
import "Tokens.js" as T

Row {
    id: islandBars

    property bool playing: false
    // Shared low-rate clock (DecorClock); without one the bars stay at their resting heights.
    property var clock: null
    property int fps: 8

    DecorClockLease {
        clock: islandBars.clock
        // Hidden bars (for example a tile layout that doesn't show them) must not keep the clock running.
        active: islandBars.playing && islandBars.visible
        fps: islandBars.fps
    }
    property color color: T.textCaption

    spacing: 4

    Repeater {
        model: [0.42, 0.88, 0.55, 0.74, 0.36]
        Rectangle {
            property real level: modelData
            width: 4
            height: Math.max(5, islandBars.height * level)
            y: (islandBars.height - height) / 2
            radius: 2
            color: islandBars.color
            opacity: islandBars.playing ? 1 : 0.45
            readonly property real lowLevel: Math.max(0.24, 1 - modelData * 0.35)
            Binding on level {
                // Hidden bars must not keep changing: even invisible items schedule a repaint when a property moves.
                when: islandBars.playing && islandBars.visible && islandBars.clock !== null
                value: Motion.cycle(islandBars.clock ? islandBars.clock.time : 0, index * 55, 210 + index * 20, 240 + index * 25, modelData, lowLevel)
            }
        }
    }
}

