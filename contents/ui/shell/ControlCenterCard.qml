pragma ComponentBehavior: Bound

import QtQuick
import "../controlcenter"
import ".."

ControlCenterModuleCard {
    id: self

    anchors.fill: parent
    hostItem: self.app.hostItem
    notificationsSource: self.app.notifications.model
    batterySource: self.app.system.battery
    connectionsSource: self.app.connectivity.connections
    screenBrightnessSource: self.app.system.screenBrightness
    keyboardBrightnessSource: self.app.system.keyboardBrightness
    powerProfilesSource: self.app.system.powerProfiles
}
