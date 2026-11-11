import QtQuick
import QtQuick.Shapes

// Dynamic Notch silhouette: flat top edge flush with the screen, small concave
// shoulders flaring into the side walls, convex bottom corners. One path is
// used for the collapsed shell and the expanded surface so they stay identical.
Item {
    id: notch

    property real shoulder: 8
    property real bottomRadius: 14
    property color fillColor: "#030304"
    property color strokeColor: "#16161b"
    property real strokeWidth: 1
    readonly property real s: Math.max(0, Math.min(shoulder, width / 2))
    readonly property real r: Math.max(0, Math.min(bottomRadius, (width - 2 * s) / 2, height - s))

    layer.enabled: true
    layer.samples: 4

    Shape {
        anchors.fill: parent

        ShapePath {
            fillColor: notch.fillColor
            strokeColor: notch.strokeColor
            strokeWidth: notch.strokeWidth
            startX: 0
            startY: 0

            PathLine {
                x: notch.width
                y: 0
            }

            PathArc {
                x: notch.width - notch.s
                y: notch.s
                radiusX: notch.s
                radiusY: notch.s
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: notch.width - notch.s
                y: notch.height - notch.r
            }

            PathArc {
                x: notch.width - notch.s - notch.r
                y: notch.height
                radiusX: notch.r
                radiusY: notch.r
                direction: PathArc.Clockwise
            }

            PathLine {
                x: notch.s + notch.r
                y: notch.height
            }

            PathArc {
                x: notch.s
                y: notch.height - notch.r
                radiusX: notch.r
                radiusY: notch.r
                direction: PathArc.Clockwise
            }

            PathLine {
                x: notch.s
                y: notch.s
            }

            PathArc {
                x: 0
                y: 0
                radiusX: notch.s
                radiusY: notch.s
                direction: PathArc.Counterclockwise
            }

        }

    }

}
