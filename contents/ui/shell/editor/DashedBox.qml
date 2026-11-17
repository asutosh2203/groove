pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../controlcenter/Tokens.js" as T

// A dashed, rounded outline: the page outline and the free cells (D-56).
Shape {
    id: box

    property color stroke: T.borderStrong
    property real radius: T.radiusInner

    ShapePath {
        strokeColor: box.stroke
        strokeWidth: 1
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [4, 4]

        PathRectangle {
            x: 0
            y: 0
            width: box.width
            height: box.height
            radius: box.radius
        }
    }
}
