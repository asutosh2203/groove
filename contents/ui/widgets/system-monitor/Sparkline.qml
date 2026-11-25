pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../controlcenter/Tokens.js" as T

// The two-minute graph (D-65): a smoothed line over a soft fill, in one Shape that is never recreated (P9); a sample only
// changes the two path strings. While the stat is hot (the hero's own state, with its hysteresis) the whole graph, line and
// fill, fades to red together: one colour at a time, so there is no seam.
Item {
    id: spark

    // { line, fill } SVG paths from SysmonHub.plot, for this item's width and (height - stroke).
    property var plot: null
    property bool hot: false
    property bool reduceMotion: false

    property color tint: spark.hot ? T.critical : T.textPrimary
    property real fillAlpha: spark.hot ? T.sysmonFillAlphaHot : T.sysmonFillAlpha
    readonly property real inset: T.sysmonSparkStroke / 2

    Behavior on tint {
        enabled: !spark.reduceMotion

        ColorAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    Behavior on fillAlpha {
        enabled: !spark.reduceMotion

        NumberAnimation {
            duration: T.motionHover
            easing.type: T.easingStandard
        }
    }

    Shape {
        y: spark.inset
        width: spark.width
        height: spark.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: spark.height - T.sysmonSparkStroke

                GradientStop {
                    position: 0
                    color: Qt.alpha(spark.tint, spark.fillAlpha)
                }

                GradientStop {
                    position: 1
                    color: Qt.alpha(spark.tint, 0)
                }
            }

            PathSvg {
                path: spark.plot ? spark.plot.fill : ""
            }
        }

        ShapePath {
            strokeColor: spark.tint
            strokeWidth: T.sysmonSparkStroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: spark.plot ? spark.plot.line : ""
            }
        }
    }
}
