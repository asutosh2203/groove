import QtQuick
import QtQuick.Shapes

// Dynamic Notch silhouette: flat top edge flush with the screen, small concave
// shoulders flaring into the side walls, convex bottom corners. One path is
// used for the collapsed shell and the expanded surface so they stay identical.
// Surface: vertical graphite gradient plus an optional 1px top "rim light"
// (the outline minus itself shifted down 1px, filled with a fading gradient).
Item {
    id: notch

    property real shoulder: 8
    property real bottomRadius: 14
    property color fillTop: "#121216"
    property color fillBottom: "#060608"
    property color strokeColor: "#16161b"
    property real strokeWidth: 1
    property real rimOpacity: 0 // 0 disables the rim light
    property real rimFade: 16
    readonly property real s: Math.max(0, Math.min(shoulder, width / 2))
    readonly property real r: Math.max(0, Math.min(bottomRadius, (width - 2 * s) / 2, height - s))

    function outline(dy) {
        const w = width, h = height;
        return "M0 " + dy + " L" + w + " " + dy
            + " A" + s + " " + s + " 0 0 0 " + (w - s) + " " + (s + dy)
            + " L" + (w - s) + " " + (h - r + dy)
            + " A" + r + " " + r + " 0 0 1 " + (w - s - r) + " " + (h + dy)
            + " L" + (s + r) + " " + (h + dy)
            + " A" + r + " " + r + " 0 0 1 " + s + " " + (h - r + dy)
            + " L" + s + " " + (s + dy)
            + " A" + s + " " + s + " 0 0 0 0 " + dy + " Z";
    }

    layer.enabled: true
    layer.samples: 4

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: notch.strokeColor
            strokeWidth: notch.strokeWidth
            fillGradient: LinearGradient {
                y1: 0
                y2: notch.height
                GradientStop { position: 0; color: notch.fillTop }
                GradientStop { position: 1; color: notch.fillBottom }
            }

            PathSvg {
                path: notch.outline(0)
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                y1: 0
                y2: notch.rimFade
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, notch.rimOpacity) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }

            PathSvg {
                path: notch.rimOpacity > 0 ? notch.outline(0) + " " + notch.outline(1) : ""
            }
        }
    }
}
