pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter"
import ".."

ControlCenterEditor {
    id: self

    required property Component cardDelegate

    hostItem: self.app.hostItem
    moduleCardDelegate: self.cardDelegate
}
