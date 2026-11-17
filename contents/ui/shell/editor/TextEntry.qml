pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import "../../controlcenter/Tokens.js" as T

// A text field in the pill style (D-56). The value is committed when editing finishes (Enter or leaving the field), not on
// every key. Esc cancels the edit first (back to the stored text), then leaves the field. It takes keyboard focus only when
// clicked (the D3 spike).
QQC2.TextField {
    id: entry

    required property var app
    required property Item focusRoot
    property string value: ""

    signal committed(string text)

    height: T.editChipH
    text: entry.value
    color: T.textPrimary
    placeholderTextColor: T.textTertiary
    font.pixelSize: T.fontBody
    selectByMouse: true
    activeFocusOnPress: true
    leftPadding: T.gap
    rightPadding: T.gap
    background: Rectangle {
        radius: entry.height / 2
        color: T.row
        border.width: 1
        border.color: entry.activeFocus ? T.textTertiary : T.border
    }
    onEditingFinished: {
        if (entry.text !== entry.value)
            entry.committed(entry.text);
    }
    onActiveFocusChanged: entry.app.editor.fieldFocused = activeFocus
    Keys.onEscapePressed: event => {
        if (entry.text !== entry.value)
            entry.text = entry.value;
        else
            entry.focusRoot.forceActiveFocus();
        event.accepted = true;
    }
}
