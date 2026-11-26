pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import "../logic/DeckPlan.js" as DeckPlan
import "Tokens.js" as T

// The Control Center header's "show the welcome tour" button (D-69): a round button the size of the pencil beside it, with a
// theme symbolic glyph (D-26). It restarts the tour and goes to its page; it is hidden while the layout is being edited.
Item {
    id: button

    required property var app
    readonly property string tooltipText: button.app.strings.tourRetake
    // Focus taken by a mouse press shows no ring; keyboard focus keeps it.
    property bool mouseFocused: false
    readonly property bool showFocusRing: button.activeFocus && !button.mouseFocused
    readonly property bool hovered: hover.hovered

    visible: !button.app.layoutService.editMode
    implicitWidth: T.headerButton
    implicitHeight: T.headerButton
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: button.tooltipText
    Accessible.onPressAction: button.app.tour.retake()
    Keys.onSpacePressed: button.app.tour.retake()
    Keys.onReturnPressed: button.app.tour.retake()
    onActiveFocusChanged: {
        if (!button.activeFocus)
            button.mouseFocused = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.pressed ? T.cardPressed : button.hovered ? T.chip : T.raised
        border.width: 1
        border.color: button.showFocusRing ? T.focusRing : T.border
    }

    ThemeGlyph {
        anchors.centerIn: parent
        width: T.headerButtonGlyph
        height: T.headerButtonGlyph
        names: DeckPlan.glyphChains.welcome
        color: T.iconActive
        opacity: mouse.pressed ? T.disabledOpacity : 1
    }

    // Hover comes from a HoverHandler: a MouseArea's containsMouse can stay stale after a press or a re-layout.
    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onPressed: {
            button.mouseFocused = true;
            button.forceActiveFocus(Qt.MouseFocusReason);
        }
        onClicked: button.app.tour.retake()
    }

    QQC2.ToolTip.visible: button.hovered || button.showFocusRing
    QQC2.ToolTip.text: button.tooltipText
    QQC2.ToolTip.delay: 350
}
