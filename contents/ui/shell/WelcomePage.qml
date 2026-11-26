pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import ".."

// The welcome tour as a deck page (D-69): one static card at a time with a stepper. A Wide page, so the copy sits beside
// a glyph. The words come from Strings.qml and the steps from Tour.js through the tour service.
Item {
    id: page

    required property var app
    readonly property var tour: page.app.tour
    readonly property var strings: page.app.strings
    readonly property var step: page.tour.view
    readonly property bool exampleStep: page.step.id === "customize"
    readonly property string exampleState: page.tour.example.state
    readonly property bool exampleUsable: page.exampleState === "ready" || page.exampleState === "exists"
    // What the card shows: it follows `step` after the fade-out, so the swap happens while the card is hidden.
    property var shown: page.tour.view
    property int travel: 1

    component TourButton: Rectangle {
        id: button

        property string text
        property bool primary: false

        signal clicked

        width: label.implicitWidth + 2 * T.padding
        height: T.editChipH
        radius: height / 2
        opacity: button.enabled ? 1 : T.disabledOpacity
        color: button.primary ? (hover.hovered ? T.fill : T.fillSoft) : (hover.hovered ? T.chip : T.row)
        border.width: 1
        border.color: button.activeFocus ? T.focusRing : T.border
        activeFocusOnTab: button.enabled
        Accessible.role: Accessible.Button
        Accessible.name: button.text
        Accessible.onPressAction: button.clicked()
        Keys.onSpacePressed: button.clicked()
        Keys.onReturnPressed: button.clicked()

        PlasmaLabel {
            id: label

            anchors.centerIn: parent
            text: button.text
            color: button.primary ? T.iconOnFill : T.textPrimary
            font.pixelSize: T.fontBody
        }

        HoverHandler {
            id: hover

            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: button.enabled
            onTapped: button.clicked()
        }
    }

    // One change of step: the card fades out, swaps and fades in with a short slide toward where the tour is heading. It runs
    // only on a change and ends with it; nothing runs while a card sits. No motion at all with reduced motion.
    Item {
        id: card

        objectName: "card"
        anchors.fill: parent
        transform: Translate {
            id: slide
        }

        Rectangle {
            id: tile

            width: T.welcomeIconTile
            height: T.welcomeIconTile
            radius: T.radiusInner
            color: T.row

            CC.ThemeGlyph {
                anchors.centerIn: parent
                width: T.welcomeIcon
                height: T.welcomeIcon
                names: page.shown.icons
                color: T.iconActive
            }
        }

        Column {
            anchors.left: tile.right
            anchors.leftMargin: T.padding
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: T.paddingCompact / 2

            PlasmaLabel {
                width: parent.width
                text: page.strings.tourTitle(page.shown.id)
                color: T.textPrimary
                font.pixelSize: T.fontTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            PlasmaLabel {
                width: parent.width
                text: page.strings.tourBody(page.shown.id)
                color: T.textSecondary
                font.pixelSize: T.fontBody
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }
    }

    // `shown` starts as a binding to `step` only so a first frame has a card; from here on it changes only through swap.
    Component.onCompleted: page.shown = page.step

    onStepChanged: {
        const from = page.shown.n;
        page.travel = page.step.n >= from ? 1 : -1;
        if (page.app.reduceMotion)
            page.shown = page.step;
        else
            swap.restart();
    }

    SequentialAnimation {
        id: swap

        objectName: "swap"

        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: T.motionFast
            easing.type: T.easingStandard
        }

        ScriptAction {
            script: {
                page.shown = page.step;
                slide.x = page.travel * T.welcomeSlide;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "opacity"
                to: 1
                duration: T.motionFade
                easing.type: T.easingStandard
            }

            NumberAnimation {
                target: slide
                property: "x"
                to: 0
                duration: T.motionFade
                easing.type: T.easingStandard
            }
        }
    }

    PlasmaLabel {
        id: counter

        // Centred under the glyph tile, which stays where it is.
        x: Math.max(0, T.welcomeIconTile / 2 - width / 2)
        anchors.verticalCenter: footer.verticalCenter
        text: page.strings.tourCounter(page.step.n, page.step.total)
        color: T.textTertiary
        font.pixelSize: T.fontBody
    }

    Row {
        id: footer

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: T.gap

        PlasmaLabel {
            // Takes only the room the counter and the buttons leave, so a long translation elides instead of overlapping.
            readonly property real room: page.width - counter.x - counter.width - 2 * T.padding - [example, skip, back, next].reduce((sum, b) => sum + (b.visible ? b.width + footer.spacing : 0), 0)

            anchors.verticalCenter: parent.verticalCenter
            visible: page.exampleStep && !page.exampleUsable
            width: Math.min(implicitWidth, Math.max(0, room))
            text: page.strings.tourExampleHint(page.exampleState)
            color: T.textTertiary
            font.pixelSize: T.fontBody
            elide: Text.ElideRight
        }

        TourButton {
            id: example

            visible: page.exampleStep
            enabled: page.exampleUsable
            text: page.exampleState === "exists" ? page.strings.tourShowExample : page.strings.tourAddExample
            onClicked: page.tour.addExample()
        }

        TourButton {
            id: skip

            visible: page.step.primary !== "done"
            text: page.strings.tourSkip
            onClicked: page.tour.finish()
        }

        TourButton {
            id: back

            visible: page.step.canBack
            text: page.strings.tourBack
            onClicked: page.tour.back()
        }

        TourButton {
            id: next

            primary: true
            text: page.step.primary === "done" ? page.strings.tourDone : page.strings.tourNext
            onClicked: page.step.primary === "done" ? page.tour.finish() : page.tour.next()
        }
    }
}
