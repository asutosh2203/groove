import QtQuick
import org.kde.notificationmanager as NotificationManager

// Plasma's Do Not Disturb as the Pomodoro timer needs it (D-64): the "inhibited until" time Plasma's own toggle writes
// (private module, recheck on Plasma upgrades). `live` follows changes made elsewhere, so the timer sees the user's own DND.
Item {
    id: dnd

    // When DND ends in ms since the epoch, or null when it is off.
    readonly property var untilMs: {
        const d = settings.notificationsInhibitedUntil;
        return d && !isNaN(d.getTime()) ? d.getTime() : null;
    }
    // Whether notifications are being held back now, whoever asked.
    readonly property bool inhibited: dnd.untilMs !== null && dnd.untilMs > Date.now()

    function setUntil(ms) {
        settings.notificationsInhibitedUntil = new Date(ms);
        settings.save();
    }

    function clear() {
        settings.notificationsInhibitedUntil = undefined;
        settings.save();
    }

    NotificationManager.Settings {
        id: settings

        live: true
    }
}
