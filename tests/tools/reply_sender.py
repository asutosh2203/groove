#!/usr/bin/env python3
"""Safe N1 test sender: posts a notification with an inline-reply action and prints every server signal.
Usage: reply_sender.py [timeout_ms] [watch_seconds] [replace]   Never talks to a real chat."""
import sys, time, dbus, dbus.mainloop.glib
from gi.repository import GLib
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
t0 = time.time()
def log(*a): print(f"[{time.time()-t0:6.2f}s]", *a, flush=True)
bus = dbus.SessionBus()
iface = dbus.Interface(bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"), "org.freedesktop.Notifications")
timeout = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
watch = int(sys.argv[2]) if len(sys.argv) > 2 else 20
hints = {"desktop-entry": "org.telegram.desktop", "x-kde-reply-placeholder-text": "Reply to Test Sender…",
         "x-kde-reply-submit-button-text": "Send", "x-kde-reply-submit-button-icon-name": "mail-send"}
nid = iface.Notify("N1 test sender", 0, "mail-message-new", "Test Sender", "Inline reply test (fake, safe)",
                   ["default", "Open", "inline-reply", "Reply"], hints, timeout)
log("posted id", int(nid), "timeout", timeout)
bus.add_signal_receiver(lambda i, r: log("NotificationClosed", int(i), "reason", int(r)), "NotificationClosed", "org.freedesktop.Notifications")
bus.add_signal_receiver(lambda i, a: log("ActionInvoked", int(i), str(a)), "ActionInvoked", "org.freedesktop.Notifications")
bus.add_signal_receiver(lambda i, t: log("NotificationReplied", int(i), repr(str(t))), "NotificationReplied", "org.freedesktop.Notifications")
GLib.timeout_add_seconds(watch, lambda: (log("done"), loop.quit()))
loop = GLib.MainLoop(); loop.run()
