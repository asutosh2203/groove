pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../controlcenter/Tokens.js" as T

// A static progress ring: it redraws only when the value changes, never on a clock.
Item {
    id: ring

    property real pct: 0
    property color color: T.textPrimary
    property color trackColor: T.borderStrong
    readonly property real radius: (ring.width - T.widgetRingStroke) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: T.widgetRingStroke
            fillColor: "transparent"

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: ring.pct > 0 ? ring.color : "transparent"
            strokeWidth: T.widgetRingStroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360 * Math.min(100, ring.pct) / 100
            }
        }
    }
}
