import QtQuick
import "WeatherCodes.js" as Codes
import "WeatherManifest.js" as Manifest

// Layered Meteocons icon. Qt SVG cannot play the packaged SMIL animations, so each layer
// (sun/moon, clouds, precipitation, bolt) is a separate static SVG animated here.
// A single phase animation drives all precipitation; nothing runs while `running` is false.
Item {
    id: icon

    property int code: -1
    property bool isDay: true
    property bool placeholder: false
    property bool running: false

    readonly property string key: placeholder ? "overcast" : Codes.iconKey(code, isDay)
    readonly property var layers: Manifest.manifest[key] || Manifest.manifest["not-available"]
    readonly property bool animated: running && !placeholder
    readonly property real u: width / 128
    property real phase: 0
    property real sunAngle: 0

    implicitWidth: 24
    implicitHeight: 24
    opacity: placeholder ? 0.5 : 1

    function src(file) {
        return Qt.resolvedUrl("icons/" + file);
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 2600
        loops: Animation.Infinite
        running: icon.animated && !!icon.layers.drops
    }

    NumberAnimation on sunAngle {
        from: 0
        to: 360
        duration: 40000
        loops: Animation.Infinite
        running: icon.animated && !!icon.layers.sun
    }

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

        SequentialAnimation on opacity {
            running: icon.animated && !!icon.layers.moon
            loops: Animation.Infinite
            NumberAnimation { to: 0.72; duration: 3200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 3200; easing.type: Easing.InOutSine }
        }
    }

    // Clouds drift slowly; the knock-out silhouette hides the sun/moon behind them and moves with them.
    Item {
        id: sky

        width: parent.width
        height: parent.height

        SequentialAnimation on x {
            running: icon.animated && !!icon.layers.clouds
            loops: Animation.Infinite
            NumberAnimation { from: -0.04 * icon.width; to: 0.04 * icon.width; duration: 4800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.04 * icon.width; to: -0.04 * icon.width; duration: 4800; easing.type: Easing.InOutSine }
        }

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
            // Resting pose (animation off) is the original artwork.
            x: !icon.animated ? 0 : fog ? Math.sin((icon.phase + index * 0.5) * Math.PI * 2) * 0.05 * icon.width : snow ? Math.sin(ph * Math.PI * 2) * 0.03 * icon.width : 0
            y: !icon.animated || fog ? 0 : ph * (snow ? 0.12 : 0.16) * icon.height
            opacity: !icon.animated || fog ? 1 : ph < 0.15 ? ph / 0.15 : ph > 0.7 ? (1 - ph) / 0.3 : 1
        }
    }

    Image {
        anchors.fill: parent
        visible: !!icon.layers.bolt
        source: icon.layers.bolt ? icon.src(icon.layers.bolt) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true
        opacity: 1

        SequentialAnimation on opacity {
            running: icon.animated && !!icon.layers.bolt
            loops: Animation.Infinite
            PauseAnimation { duration: 3400 }
            NumberAnimation { to: 0.15; duration: 60 }
            NumberAnimation { to: 1; duration: 70 }
            NumberAnimation { to: 0.35; duration: 60 }
            NumberAnimation { to: 1; duration: 140 }
        }
    }

    Image {
        anchors.fill: parent
        visible: !!icon.layers.whole
        source: icon.layers.whole ? icon.src(icon.layers.whole) : ""
        sourceSize: Qt.size(64, 64)
        mipmap: true
    }
}
