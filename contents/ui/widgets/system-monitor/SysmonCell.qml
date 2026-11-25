pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Island
import "../../controlcenter/Tokens.js" as T
import ".." as Widgets

// One stat (D-65), also the 1x1 block of the 2x1 and 4x1: the label, the hero (red while hot, with hysteresis), a small
// suffix and the two-minute line; a tall box adds the line Kove chooses for the stat. A stat whose sensor is missing or
// silent says so here and leaves the other cells alone.
Item {
    id: cell

    required property var base
    required property string kind
    readonly property var face: cell.base.hub ? cell.base.hub.face(cell.kind) : null
    readonly property bool ready: cell.face?.state === "ready"
    readonly property bool failed: cell.face?.state === "error"
    readonly property string companion: cell.ready && cell.base.tall && cell.base.s ? cell.base.s.sysmonCompanion(cell.face.companion) : ""

    Widgets.TileFace {
        id: tile

        anchors.fill: parent
        anchors.margins: T.widgetPadding
        label: cell.base.s ? cell.base.s.sysmonLabel(cell.kind) : ""
        hero: cell.ready ? cell.face.hero : ""
        heroSuffix: cell.ready ? cell.face.suffix : ""
        heroColor: cell.face?.hot ? T.critical : T.textPrimary
        heroSize: T.widgetHeroSizeSmall + 4
        heroShift: spark.height / 2
        detail: cell.companion

        Sparkline {
            id: spark

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: cell.companion.length > 0 ? tile.detailItem.height + T.gap : 0
            height: tile.height * 0.3
            visible: cell.ready
            hot: cell.face?.hot ?? false
            reduceMotion: cell.base.reduceMotion
            plot: cell.ready ? cell.base.hub.plot(cell.kind, spark.width, spark.height - T.sysmonSparkStroke) : null
        }

        Island.PlasmaLabel {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: cell.failed
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: T.textSecondary
            font.pixelSize: T.fontCaption
            text: cell.failed && cell.base.s ? cell.base.s.sysmonError(cell.kind, cell.face.reason) : ""
        }
    }
}
