import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "controlcenter/Tokens.js" as T

Item {
    id: control

    property real from: 0
    property real to: 100
    property real value: 0
    property color accent: T.fill
    property color trackColor: "#24242b"
    // D-45: the fill brightens toward the tip and a static glow sits on the leading edge (job bars).
    property bool tipGradient: false
    property bool glow: false
    property bool dimmed: false
    readonly property real safeFrom: isFinite(Number(from)) ? Number(from) : 0
    readonly property real safeTo: isFinite(Number(to)) ? Number(to) : safeFrom + 1
    readonly property real safeValue: isFinite(Number(value)) ? Number(value) : safeFrom
    readonly property real amount: Math.max(0, Math.min(1, (safeValue - safeFrom) / Math.max(1, safeTo - safeFrom)))

    implicitHeight: 8
    opacity: dimmed ? T.disabledOpacity : 1

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: control.trackColor
    }

    Rectangle {
        id: fill

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(parent.height, parent.width * control.amount)
        radius: height / 2
        color: control.accent
        gradient: control.tipGradient ? tipFill : null
    }

    Gradient {
        id: tipFill

        orientation: Gradient.Horizontal

        GradientStop { position: 0; color: T.progressTipFrom }
        GradientStop { position: T.progressTipMidStop; color: T.progressTipMid }
        GradientStop { position: 1; color: T.progressTipEnd }
    }

    // Redrawn only when the progress changes: nothing animates.
    Item {
        id: glowHead

        width: T.progressGlowW
        height: T.progressGlowH
        x: fill.width - width / 2
        y: (control.height - height) / 2
        visible: control.glow && !control.dimmed && control.amount > 0 && control.amount < 1
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 16
            blur: T.progressGlowBlur / 16
        }

        Shape {
            y: (glowHead.height - glowHead.width) / 2
            width: glowHead.width
            height: glowHead.width
            transform: Scale {
                origin.x: glowHead.width / 2
                origin.y: glowHead.width / 2
                yScale: glowHead.height / glowHead.width
            }

            ShapePath {
                strokeColor: "transparent"
                startX: 0
                startY: 0

                fillGradient: RadialGradient {
                    centerX: glowHead.width / 2
                    centerY: glowHead.width / 2
                    centerRadius: glowHead.width / 2
                    focalX: centerX
                    focalY: centerY

                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, T.progressGlowCore) }
                    GradientStop { position: T.progressGlowMidStop; color: Qt.rgba(1, 1, 1, T.progressGlowMid) }
                    GradientStop { position: T.progressGlowEndStop; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }

                PathLine { x: glowHead.width; y: 0 }
                PathLine { x: glowHead.width; y: glowHead.width }
                PathLine { x: 0; y: glowHead.width }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
