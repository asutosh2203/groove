# Test tools

`reply_sender.py [timeout_ms] [watch_seconds]` posts a fake "Test Sender" notification with an inline-reply action
over D-Bus and prints `NotificationClosed`, `ActionInvoked` and `NotificationReplied`, so the reply shelf can be tested
end to end without touching a real chat. It needs `python-dbus` and `python-gobject`, and a running notification server.
