import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ".."
import "Tokens.js" as T

Item {
    id: controlSlider

    required property var app
    property string title: ""
    property string iconName: ""
    property string valueText: ""
    property real value: 0
    property real toValue: 100
    property string actionIconName: ""
    property string secondaryActionIconName: ""
    property string actionTooltip: ""
    property string secondaryActionTooltip: ""
    // A missing audio sink or backlight should disable the slider, not the
    // settings action buttons in the corner of the tile.
    property bool sliderEnabled: true
    readonly property bool sliderAvailable: enabled && sliderEnabled
    readonly property real safeToValue: Math.max(1, app.finiteNumber(toValue, 100))
    readonly property real safeValue: Math.max(0, Math.min(safeToValue, app.finiteNumber(value, 0)))
    readonly property real ratio: safeValue / safeToValue
    readonly property real fillRatio: ratio
    readonly property real cornerRadius: Math.min(T.radiusCard, Math.min(width, height) / 2)
    // Whether the neutral fill reaches the value label / glyph so their
    // colour can flip to stay readable on the light fill.
    // Fill length along the slider axis, including the minimum rounded cap.
    readonly property real fillExtent: vertical ? Math.max(fillRatio > 0 ? Math.min(width, height) : 0, height * fillRatio) : Math.max(fillRatio > 0 ? Math.min(width, height) : 0, width * fillRatio)
    readonly property bool iconCovered: vertical ? fillExtent > iconSize + 10 : fillExtent > iconSize + 14
    readonly property bool valueCovered: vertical ? fillExtent > height - 24 : fillExtent > 10 + valueLabelWidth + 4
    readonly property real iconSize: Math.max(16, Math.min(26, width - 14, height - 14))
    readonly property real valueLabelWidth: 40
    readonly property bool vertical: height > width * 1.25
    readonly property bool showActions: width >= 142 && height >= 72 && (actionIconName.length > 0 || secondaryActionIconName.length > 0)
    readonly property real keyboardStep: Math.max(1, Math.round(safeToValue / 20))

    signal moved(real value)
    signal actionTriggered()
    signal secondaryActionTriggered()

    implicitHeight: 116
    activeFocusOnTab: sliderAvailable
    Accessible.role: Accessible.Slider
    Accessible.name: title
    Accessible.description: valueText
    Accessible.onIncreaseAction: adjustBy(keyboardStep)
    Accessible.onDecreaseAction: adjustBy(-keyboardStep)
    Keys.onLeftPressed: adjustBy(-keyboardStep)
    Keys.onRightPressed: adjustBy(keyboardStep)
    Keys.onUpPressed: adjustBy(keyboardStep)
    Keys.onDownPressed: adjustBy(-keyboardStep)

    function adjustBy(delta) {
        if (!sliderAvailable)
            return ;
        controlSlider.moved(Math.max(0, Math.min(safeToValue, safeValue + delta)));
    }

    Rectangle {
        anchors.fill: parent
        radius: controlSlider.cornerRadius
        color: T.sliderTrack
        border.color: controlSlider.activeFocus ? T.focusRing : "transparent"
        border.width: 1
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: controlSlider.vertical ? parent.width : controlSlider.fillExtent
            height: controlSlider.vertical ? controlSlider.fillExtent : parent.height
            radius: controlSlider.cornerRadius
            color: T.fill
            opacity: controlSlider.sliderAvailable ? (app.controlEditMode ? 0.7 : 1) : 0.16

            Behavior on width { NumberAnimation { duration: T.motionSlider; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: T.motionSlider; easing.type: Easing.OutCubic } }
        }
    }

    Kirigami.Icon {
        id: sliderGlyph

        width: controlSlider.iconSize
        height: width
        x: controlSlider.vertical ? Math.round((parent.width - width) / 2) : 12
        y: controlSlider.vertical ? parent.height - height - 10 : Math.round((parent.height - height) / 2)
        source: T.symbolic(controlSlider.iconName)
        isMask: true
        color: controlSlider.iconCovered && controlSlider.sliderAvailable ? T.iconOnFill : T.iconIdle
        opacity: controlSlider.sliderAvailable ? 1 : T.disabledOpacity

        Behavior on color { ColorAnimation { duration: T.motionFast } }
    }

    PlasmaLabel {
        visible: controlSlider.width >= 116 && !controlSlider.showActions
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        text: controlSlider.valueText
        color: controlSlider.valueCovered && controlSlider.sliderAvailable ? T.iconOnFill : T.textCaption
        font.pixelSize: T.fontCaption
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    QQC2.ToolTip.visible: hoverArea.containsMouse
    QQC2.ToolTip.text: controlSlider.title + " " + controlSlider.valueText
    QQC2.ToolTip.delay: 350

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: controlSlider.sliderAvailable && !app.controlEditMode
        preventStealing: true

        function valueFromMouse(mouse) {
            const pct = controlSlider.vertical ? 1 - mouse.y / Math.max(1, height) : mouse.x / Math.max(1, width);
            return Math.round(Math.max(0, Math.min(1, pct)) * controlSlider.safeToValue);
        }

        onPressed: (mouse) => {
            controlSlider.forceActiveFocus();
            mouse.accepted = true;
            controlSlider.moved(valueFromMouse(mouse));
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                mouse.accepted = true;
                controlSlider.moved(valueFromMouse(mouse));
            }
        }
    }

    Row {
        visible: controlSlider.showActions
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6
        z: 3

        IslandButton {
            visible: controlSlider.actionIconName.length > 0
            width: 26
            height: 26
            compact: true
            restColor: T.raised
            hoverColor: T.chip
            pressedColor: T.cardPressed
            outlineColor: T.border
            focusColor: T.focusRing
            iconName: controlSlider.actionIconName
            tooltipText: controlSlider.actionTooltip
            onClicked: controlSlider.actionTriggered()
        }

        IslandButton {
            visible: controlSlider.secondaryActionIconName.length > 0
            width: 26
            height: 26
            compact: true
            restColor: T.raised
            hoverColor: T.chip
            pressedColor: T.cardPressed
            outlineColor: T.border
            focusColor: T.focusRing
            iconName: controlSlider.secondaryActionIconName
            tooltipText: controlSlider.secondaryActionTooltip
            onClicked: controlSlider.secondaryActionTriggered()
        }
    }

    PlasmaLabel {
        visible: controlSlider.showActions && controlSlider.width >= 180
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        text: controlSlider.valueText
        color: controlSlider.valueCovered && controlSlider.sliderAvailable ? T.iconOnFill : T.textCaption
        font.pixelSize: T.fontCaption
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}

