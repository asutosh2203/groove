import QtQuick
import QtQuick.Shapes

// Dynamic Pill surface (rounded rectangle, capsule when radius >= height / 2) with the
// same graphite gradient and optional top rim light as NotchShape.
Item {
    id: round

    property real radius: height / 2
    property color fillTop: "#121216"
    property color fillBottom: "#060608"
    property color strokeColor: "#16161b"
    property real strokeWidth: 1
    property real rimOpacity: 0
    property real rimFade: 16
    readonly property real r: Math.max(0, Math.min(radius, width / 2, height / 2))

    function outline(dy) {
        const w = width, h = height;
        return "M" + r + " " + dy + " L" + (w - r) + " " + dy
            + " A" + r + " " + r + " 0 0 1 " + w + " " + (r + dy)
            + " L" + w + " " + (h - r + dy)
            + " A" + r + " " + r + " 0 0 1 " + (w - r) + " " + (h + dy)
            + " L" + r + " " + (h + dy)
            + " A" + r + " " + r + " 0 0 1 0 " + (h - r + dy)
            + " L0 " + (r + dy)
            + " A" + r + " " + r + " 0 0 1 " + r + " " + dy + " Z";
    }

    layer.enabled: true
    layer.samples: 4

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: round.strokeColor
            strokeWidth: round.strokeWidth
            fillGradient: LinearGradient {
                y1: 0
                y2: round.height
                GradientStop { position: 0; color: round.fillTop }
                GradientStop { position: 1; color: round.fillBottom }
            }

            PathSvg {
                path: round.outline(0)
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                y1: 0
                y2: round.rimFade
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, round.rimOpacity) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }

            PathSvg {
                path: round.rimOpacity > 0 ? round.outline(0) + " " + round.outline(1) : ""
            }
        }
    }
}
