pragma ComponentBehavior: Bound

import QtQuick
import "../activities" as Activities

Activities.NotificationVisual {
    id: self

    required property var app

    source: self.app.notifications.appIcon(self.app.notifications.latestRow())
    fallbackSource: "notifications"
    fallbackColor: self.app.notifications.accent(self.app.notifications.latestRow())
}
