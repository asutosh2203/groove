pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2

// A settings combo box that shows the saved choice. Its row comes from the rows themselves: indexOfValue() runs before the
// model exists, so a saved second option showed the first.
QQC2.ComboBox {
    id: combo

    // [{ text, value }]
    property var rows: []
    // The saved value.
    property string selected: ""

    textRole: "text"
    valueRole: "value"
    model: combo.rows
    currentIndex: Math.max(0, combo.rows.findIndex(row => row.value === combo.selected))
}
