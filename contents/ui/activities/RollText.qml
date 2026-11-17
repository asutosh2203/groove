pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter/Tokens.js" as T

// A one-line label whose text rolls: the old text slides up and out while the new one slides in from below (D-57). It
// animates only when the text changes (P9); `duration` 0 (reduced motion) swaps it at once.
Item {
    id: roll

    required property string text
    required property color color
    property int duration: T.motionFade
    // 0: the old text is leaving and the new one arriving; 1: settled.
    property real progress: 1

    implicitWidth: current.implicitWidth
    implicitHeight: current.implicitHeight
    clip: true

    onTextChanged: {
        if (current.text === "" || roll.duration === 0) {
            current.text = roll.text;
            return;
        }
        previous.text = current.text;
        current.text = roll.text;
        slide.restart();
    }

    NumberAnimation {
        id: slide

        target: roll
        property: "progress"
        from: 0
        to: 1
        duration: roll.duration
        easing.type: T.easingStandard
    }

    PlasmaLabel {
        id: previous

        width: parent.width
        y: -roll.progress * roll.height
        visible: roll.progress < 1
        color: roll.color
        font.pixelSize: T.fontCaption
        font.weight: Font.DemiBold
    }

    PlasmaLabel {
        id: current

        width: parent.width
        y: (1 - roll.progress) * roll.height
        color: roll.color
        font.pixelSize: T.fontCaption
        font.weight: Font.DemiBold
    }
}
