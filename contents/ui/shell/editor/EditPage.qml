pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T

// The edit mode's page (D-56), laid out in the silhouette's body: a top bar, the grid or form (or the Control Center tile
// editor), the chips bar, and the discard prompt over it all.
Item {
    id: page

    required property var app
    required property Item focusRoot
    required property Component controlPage
    readonly property var ed: page.app.editor
    readonly property real contentTop: T.editInset + T.editBar + T.editGap
    readonly property real contentBottom: page.height - T.editInset - T.editChips - T.editGap

    // A drag from a widget or a catalogue row (D-56). The sources report through dragBegin, dragMove and dragEnd; the grid
    // decides what the drop means. pos is in this page's coordinates.
    QtObject {
        id: dragState

        property bool active: false
        property point pos: Qt.point(0, 0)
        property var payload: null
        property real ghostW: 0
        property real ghostH: 0
    }

    function dragBegin(payload, w, h) {
        dragState.payload = payload;
        dragState.ghostW = w;
        dragState.ghostH = h;
        dragState.active = true;
    }

    function dragMove(scenePos) {
        dragState.pos = page.mapFromItem(null, scenePos.x, scenePos.y);
    }

    function dragEnd() {
        if (!dragState.active)
            return ;
        dragState.active = false;
        const grid = gridLoader.item as EditGrid;
        if (grid)
            grid.drop(dragState.pos, dragState.payload);
    }

    EditTopBar {
        x: T.editInset
        y: T.editInset
        width: page.width - 2 * T.editInset
        height: T.editBar
        app: page.app
    }

    Item {
        x: T.editInset
        y: page.contentTop
        width: page.width - 2 * T.editInset
        height: page.contentBottom - page.contentTop

        Loader {
            id: gridLoader

            anchors.fill: parent
            active: page.ed.view === "preset" && page.ed.pane === "grid"

            sourceComponent: EditGrid {
                app: page.app
                drag: dragState
                host: page
            }
        }

        Loader {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: T.editSidebar
            active: page.ed.view === "preset" && page.ed.pane === "grid"

            sourceComponent: EditCatalogue {
                app: page.app
                drag: dragState
                host: page
            }
        }

        Loader {
            anchors.fill: parent
            active: page.ed.view === "preset" && page.ed.pane === "form"

            sourceComponent: SettingsForm {
                app: page.app
                focusRoot: page.focusRoot
            }
        }

        Loader {
            anchors.fill: parent
            active: page.ed.view === "gear"
            sourceComponent: page.controlPage
        }
    }

    ChipsBar {
        x: T.editInset
        y: page.height - T.editInset - T.editChips + (T.editChips - T.editChipH) / 2
        width: page.width - 2 * T.editInset
        app: page.app
    }

    // The widget being dragged follows the pointer.
    Rectangle {
        visible: dragState.active
        x: dragState.pos.x - width / 2
        y: dragState.pos.y - height / 2
        width: dragState.ghostW
        height: dragState.ghostH
        radius: T.radiusInner
        color: T.chip
        opacity: T.disabledOpacity
        border.width: 1
        border.color: T.borderStrong
    }

    Loader {
        anchors.fill: parent
        active: page.ed.promptOpen

        sourceComponent: DiscardPrompt {
            app: page.app
        }
    }
}
