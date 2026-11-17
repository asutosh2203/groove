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
            anchors.fill: parent
            active: page.ed.view === "preset" && page.ed.pane === "grid"

            sourceComponent: EditGrid {
                app: page.app
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
        app: page.app
    }

    Loader {
        anchors.fill: parent
        active: page.ed.promptOpen

        sourceComponent: DiscardPrompt {
            app: page.app
        }
    }
}
