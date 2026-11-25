pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import "../../controlcenter/Tokens.js" as T

// The page an enum field opens (D-64): a two-column grid of option chips, the chosen one raised with a ✓, an option the machine
// lacks dimmed with a short note and out of reach of both pointer and keyboard. Nothing floats: the form slides away and this
// slides in. options: [{ value, label, enabled? }].
FocusScope {
    id: page

    property var options: []
    property string value: ""
    property string missingText: ""
    // The chip with the keyboard focus ring; -1 until one is chosen.
    property int current: -1
    readonly property int columns: 2
    readonly property real chipW: (page.width - T.gap) / page.columns

    signal picked(string value)

    function usable(i) {
        return i >= 0 && i < page.options.length && page.options[i].enabled !== false;
    }

    // The next usable chip from `from` in steps of `step`, or `from` when there is none that way.
    function next(from, step) {
        for (let i = from + step; i >= 0 && i < page.options.length; i += step)
            if (page.usable(i))
                return i;
        return from;
    }

    function choose(i) {
        if (page.usable(i))
            page.picked(page.options[i].value);
    }

    // Open on the chosen option, else the first usable one.
    function focusStart() {
        const chosen = page.options.findIndex(o => o.value === page.value);
        page.current = page.usable(chosen) ? chosen : page.next(-1, 1);
        page.forceActiveFocus();
    }

    Component.onCompleted: page.focusStart()

    Keys.onLeftPressed: page.current = page.next(page.current, -1)
    Keys.onRightPressed: page.current = page.next(page.current, 1)
    Keys.onUpPressed: page.current = page.next(page.current, -page.columns)
    Keys.onDownPressed: page.current = page.next(page.current, page.columns)
    Keys.onReturnPressed: page.choose(page.current)
    Keys.onEnterPressed: page.choose(page.current)
    Keys.onSpacePressed: page.choose(page.current)

    Repeater {
        model: page.options

        delegate: Rectangle {
            id: chip

            required property int index
            required property var modelData
            readonly property bool usable: chip.modelData.enabled !== false
            readonly property bool chosen: chip.modelData.value === page.value

            x: (chip.index % page.columns) * (page.chipW + T.gap)
            y: Math.floor(chip.index / page.columns) * (T.editEntry + T.gap)
            width: page.chipW
            height: T.editEntry
            radius: T.radiusInner
            color: chip.chosen ? T.chip : chip.usable && hover.hovered ? T.rowHover : T.row
            border.width: 1
            border.color: page.activeFocus && page.current === chip.index ? T.focusRing : chip.chosen ? T.borderStrong : T.border
            opacity: chip.usable ? 1 : T.disabledOpacity
            Accessible.role: Accessible.Button
            Accessible.name: chip.modelData.label
            Accessible.checked: chip.chosen

            PlasmaLabel {
                anchors.left: parent.left
                anchors.leftMargin: T.padding
                anchors.right: tail.left
                anchors.rightMargin: T.gap
                anchors.verticalCenter: parent.verticalCenter
                text: chip.modelData.label
                elide: Text.ElideRight
                color: chip.usable ? T.textPrimary : T.textTertiary
                font.pixelSize: T.fontHeader
            }

            PlasmaLabel {
                id: tail

                anchors.right: parent.right
                anchors.rightMargin: T.padding
                anchors.verticalCenter: parent.verticalCenter
                text: !chip.usable ? page.missingText : chip.chosen ? "✓" : ""
                color: chip.usable ? T.textPrimary : T.textTertiary
                font.pixelSize: chip.usable ? T.fontHeader : T.fontCaption
            }

            HoverHandler {
                id: hover

                enabled: chip.usable
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: chip.usable
                onTapped: {
                    page.current = chip.index;
                    page.choose(chip.index);
                }
            }
        }
    }
}
