import QtQuick
import ".."
import "../DecorMotion.js" as Motion
import "WeatherCodes.js" as Codes
import "WeatherManifest.js" as Manifest

// Layered Meteocons icon. Qt SVG cannot play the packaged SMIL animations, so each layer
// (sun/moon, clouds, precipitation, bolt) is a separate static SVG animated here.
// All motion is a function of the shared DecorClock's time, so the icon is redrawn at the clock's low rate
// (D-34); nothing ticks while `running` is false or there is no clock.
Item {
    id: icon

    property int code: -1
    property bool isDay: true
    property bool placeholder: false
    property bool running: false
    property var clock: null
    property int fps: 8

    readonly property string key: placeholder ? "overcast" : Codes.iconKey(code, isDay)
    readonly property var layers: Manifest.manifest[key] || Manifest.manifest["not-available"]
    readonly property bool animated: running && !placeholder
    readonly property real u: width / 128
    // Hidden icons must not keep changing either: even invisible items schedule a repaint when a property moves.
    readonly property bool driven: animated && visible && clock !== null && clock !== undefined
    readonly property real now: driven ? clock.time : 0
    readonly property bool hasMotion: !!layers.drops || !!layers.stars || !!layers.sun || !!layers.moon || !!layers.bolt || cloudsOnly

    DecorClockLease {
        clock: icon.clock
        active: icon.animated && icon.hasMotion
        fps: icon.fps
    }

    // Rain, snow, fog and star twinkle share one phase; the sun turns slowly.
    readonly property int phasePeriod: layers.stars ? 3000 : dropKind === "fog" ? 6000 : dropKind === "snow" ? 3600 : 1700
    readonly property real phase: driven && (!!layers.drops || !!layers.stars) ? Motion.phase(now, phasePeriod) : 0
    readonly property real sunAngle: driven && !!layers.sun ? Motion.phase(now, 18000) * 360 : 0

    implicitWidth: 24
    implicitHeight: 24
    opacity: placeholder ? 0.5 : 1

    function src(file) {
        return Qt.resolvedUrl("icons/" + file);
    }

    // Period per precipitation kind: rain falls quickly, snow falls slowly, fog fades slowly.
    readonly property string dropKind: layers.drops && layers.drops.length > 0 ? layers.drops[0].k : ""

    Image {
        anchors.fill: parent
        visible: !!icon.layers.sun
        source: icon.layers.sun ? icon.src(icon.layers.sun) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true
        transform: Rotation {
            origin.x: icon.layers.pivot ? icon.layers.pivot[0] * icon.u : 0
            origin.y: icon.layers.pivot ? icon.layers.pivot[1] * icon.u : 0
            angle: icon.sunAngle
        }
    }

    Image {
        id: moon

        anchors.fill: parent
        visible: !!icon.layers.moon
        source: icon.layers.moon ? icon.src(icon.layers.moon) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true

        opacity: icon.driven && !!icon.layers.moon ? Motion.sway(icon.now, 2600, 1, 0.7) : 1
    }

    // Night sky: three four-point sparkles twinkle out of step (opacity and a small scale pulse).
    Repeater {
        model: icon.layers.stars || []

        Image {
            id: star

            required property var modelData
            required property int index
            readonly property real tw: 0.5 + 0.5 * Math.sin((icon.phase + index / 3) * Math.PI * 2)

            anchors.fill: parent
            source: icon.src(modelData.f)
            sourceSize: Qt.size(64, 64)
            mipmap: true
            opacity: icon.animated ? 0.3 + 0.7 * tw : 1
            transform: Scale {
                origin.x: modelData.cx * icon.u
                origin.y: modelData.cy * icon.u
                xScale: icon.animated ? 0.75 + 0.3 * star.tw : 1
                yScale: xScale
            }
        }
    }

    // Clouds only drift sideways when nothing else in the icon moves (overcast); the knock-out
    // silhouette hides the sun/moon behind them.
    readonly property bool cloudsOnly: !!layers.clouds && !layers.sun && !layers.moon && !layers.drops && !layers.bolt

    Item {
        id: sky

        width: parent.width
        height: parent.height

        x: icon.driven && icon.cloudsOnly ? Motion.sway(icon.now, 3200, -0.09, 0.09) * icon.width : 0

        Image {
            anchors.fill: parent
            visible: !!icon.layers.knock
            source: icon.layers.knock ? icon.src(icon.layers.knock) : ""
            sourceSize: Qt.size(64, 64)
            mipmap: true
        }

        Image {
            anchors.fill: parent
            visible: !!icon.layers.clouds
            source: icon.layers.clouds ? icon.src(icon.layers.clouds) : ""
            sourceSize: Qt.size(64, 64)
            mipmap: true
        }
    }

    Repeater {
        model: icon.layers.drops || []

        Image {
            required property var modelData
            required property int index
            readonly property real ph: (icon.phase + index / 3) % 1
            readonly property bool fog: modelData.k === "fog"
            readonly property bool snow: modelData.k === "snow"

            anchors.fill: parent
            source: icon.src(modelData.f)
            sourceSize: Qt.size(64, 64)
            mipmap: true
            // Resting pose (animation off) is the original artwork. Falling uses a transform because
            // anchors.fill pins x/y. Fog never moves sideways: its lines just fade in and out.
            transform: Translate {
                y: !icon.animated || fog ? 0 : ph * (snow ? 0.2 : 0.24) * icon.height
            }
            opacity: !icon.animated ? 1 : fog ? 0.55 + 0.45 * (0.5 + 0.5 * Math.sin((icon.phase + index * 0.5) * Math.PI * 2)) : ph < 0.15 ? ph / 0.15 : ph > 0.7 ? (1 - ph) / 0.3 : 1
        }
    }

    Image {
        anchors.fill: parent
        visible: !!icon.layers.bolt
        source: icon.layers.bolt ? icon.src(icon.layers.bolt) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true
        opacity: icon.driven && !!icon.layers.bolt ? Motion.bolt(icon.now) : 1
    }

    Image {
        anchors.fill: parent
        visible: !!icon.layers.whole
        source: icon.layers.whole ? icon.src(icon.layers.whole) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true
    }
}
