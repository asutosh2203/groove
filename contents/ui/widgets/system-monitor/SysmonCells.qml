pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T

// The stats of a span (D-65): the 1x1 cell repeated, a hairline between, as in the other widgets.
Item {
    id: cells

    required property var base
    readonly property real cellWidth: (cells.width - T.gap * (cells.base.kinds.length - 1)) / Math.max(1, cells.base.kinds.length)

    Repeater {
        model: cells.base.kinds

        delegate: SysmonCell {
            id: cell

            required property int index
            required property string modelData

            x: cell.index * (cells.cellWidth + T.gap)
            width: cells.cellWidth
            height: cells.height
            base: cells.base
            kind: cell.modelData
        }
    }

    Repeater {
        model: Math.max(0, cells.base.kinds.length - 1)

        delegate: Rectangle {
            id: line

            required property int index

            x: (line.index + 1) * (cells.cellWidth + T.gap) - T.gap / 2
            y: T.widgetPadding
            width: 1
            height: cells.height - 2 * T.widgetPadding
            color: Qt.alpha(T.borderStrong, T.liveHairlineAlpha)
        }
    }
}
