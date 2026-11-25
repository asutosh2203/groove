import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Posts a notification through the session bus (org.freedesktop.Notifications.Notify) and reports the id the server gave
// it. No actions: a button in a native popup would be dead, because QML cannot receive ActionInvoked; Kove's own pop-in
// draws its Start button from the id instead (D-64).
QtObject {
    function post(summary, body, icon, onId) {
        const reply = DBus.SessionBus.asyncCall({
            "service": "org.freedesktop.Notifications",
            "path": "/org/freedesktop/Notifications",
            "iface": "org.freedesktop.Notifications",
            "member": "Notify",
            "arguments": [new DBus.string("Kove"), new DBus.uint32(0), new DBus.string(icon), new DBus.string(summary), new DBus.string(body), [], new DBus.dict({}), new DBus.int32(-1)]
        });
        reply.finished.connect(() => {
            if (!reply.isError && onId)
                onId(Number(reply.value));
        });
    }
}
