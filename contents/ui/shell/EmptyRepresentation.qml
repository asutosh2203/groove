pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: self

    required property var app

    implicitWidth: self.app.islandWidth
    implicitHeight: self.app.islandHeight
    width: implicitWidth
    height: implicitHeight
    visible: false
}
