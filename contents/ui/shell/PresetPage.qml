pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter/Tokens.js" as T
import "../logic/Presets.js" as Presets

// A preset page (D-54): its placements packed row by row into the page's content area. Every slot gets its pixel box
// from here, so a widget never needs to know the cell sizes.
Item {
    id: page

    required property var app
    // Set by the deck after loading, like the dev label before it.
    property string pageId
    readonly property var preset: page.app.deck.presetFor(page.pageId)
    readonly property var placements: page.preset ? page.preset.placements : []
    readonly property var boxes: page.preset ? Presets.boxes(page.preset.type, page.width, page.height, T.gap, page.placements) : []

    Repeater {
        // A count, not the array: a Repeater over a JS array rebuilds every delegate on any change.
        model: page.boxes.length

        delegate: WidgetSlot {
            id: slotItem

            required property int index

            app: page.app
            placement: page.placements[slotItem.index]
            x: page.boxes[slotItem.index].x
            y: page.boxes[slotItem.index].y
            width: page.boxes[slotItem.index].w
            height: page.boxes[slotItem.index].h
        }
    }
}
