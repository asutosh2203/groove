#!/usr/bin/env python3
"""The per-user agent aggregator (D-57): owns io.github.asutosh2203.Kove.Agents on the session bus, takes hook events on
one Unix socket and publishes every session as a JSON snapshot. Started by the first hook, exits when idle.
The first event arrives on stdin from the spawning hook; later ones over the socket. Content stays in memory."""
import json
import os
import socket
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kove_logic as L
from kove_hook import log, sock_path

BUS_NAME = "io.github.asutosh2203.Kove.Agents"
OBJ_PATH = "/io/github/asutosh2203/Kove/Agents"
IFACE = "io.github.asutosh2203.Kove.Agents1"
IDLE_EXIT = float(os.environ.get("KOVE_CLAUDE_IDLE_EXIT_SECONDS", "60"))
DRY = os.environ.get("KOVE_TEST_NO_NOTIFY") == "1"  # tests only: no real notification
DONE_MIN = float(os.environ.get("KOVE_CLAUDE_DONE_MIN_SECONDS", "30"))


def forward(data):
    """Lost the bus-name race: hand the first event to the winner once its socket is up."""
    for _ in range(20):
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(sock_path())
            s.sendall(data)
            s.close()
            return
        except OSError:
            time.sleep(0.1)


def main():
    import dbus
    import dbus.mainloop.glib
    import dbus.service
    from gi.repository import GLib
    first = sys.stdin.buffer.read()
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    if bus.request_name(BUS_NAME, dbus.bus.NAME_FLAG_DO_NOT_QUEUE) != dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER:
        return forward(first)

    hub, last, routes, timer = L.Hub(DONE_MIN), [None], L.Routes(), [None]

    def notifier():
        return dbus.Interface(bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"),
                              "org.freedesktop.Notifications")

    class Agents(dbus.service.Object):
        @dbus.service.method(IFACE, out_signature="s")
        def List(self):
            return json.dumps(hub.snapshot())

        @dbus.service.signal(IFACE, signature="s")
        def Changed(self, snapshot):
            pass

        @dbus.service.signal(IFACE, signature="s")
        def RaiseRequested(self, session_id):
            pass

    svc = Agents(bus, OBJ_PATH)

    def publish():
        snap = hub.snapshot()
        key = json.dumps([[{k: v for k, v in s.items() if k != "updatedAt"} for s in snap["sessions"]], snap.get("usage")])
        if key != last[0]:
            last[0] = key
            svc.Changed(json.dumps(snap))

    def apply(actions):
        for a in actions:
            hints = {"urgency": dbus.Byte(2 if a["urgent"] else 1)}  # no desktop entry: a guessed app is never opened (D-57)
            if DRY:
                nid = 1000 + len(routes.ids)
            else:
                nid = int(notifier().Notify("Claude Code", dbus.UInt32(0), "", a["summary"], a["body"],
                                       ["default", "Open"], hints, -1))
            routes.remember(nid, a["sid"])

    def on_action(nid, key):
        sid = routes.session_for(int(nid), str(key))
        if sid:
            svc.RaiseRequested(sid)  # Kove matches the window; with no Kove running the click only dismisses

    bus.add_signal_receiver(on_action, "ActionInvoked", "org.freedesktop.Notifications")

    def on_event(data):
        try:
            apply(L.ingest(hub, data, time.time(), log))
        except Exception as e:
            log("notify: %s" % type(e).__name__)
        publish()
        schedule()

    path = sock_path()
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    if os.path.exists(path):  # owning the bus name proves no other aggregator is alive
        os.unlink(path)
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(path)
    os.chmod(path, 0o600)
    srv.listen(8)
    srv.setblocking(False)
    loop = GLib.MainLoop()

    def on_connect(*_):
        try:
            conn, _a = srv.accept()
            conn.settimeout(1)
            with conn:
                data = b""
                while chunk := conn.recv(65536):
                    data += chunk
            on_event(data)
        except OSError as e:
            log("socket: %s" % type(e).__name__)
        return True

    def tick():
        timer[0] = None
        now = time.time()
        if hub.tick(now):
            publish()
        if hub.idle_for(now) >= IDLE_EXIT:
            loop.quit()
            return False
        schedule()
        return False

    def schedule():
        """One wakeup, at the next expiry or the idle exit; none at all while only waiting sessions remain."""
        if timer[0] is not None:
            GLib.source_remove(timer[0])
            timer[0] = None
        due = hub.deadline(time.time(), IDLE_EXIT)
        if due is not None:
            timer[0] = GLib.timeout_add(max(50, int((due - time.time()) * 1000) + 50), tick)

    GLib.io_add_watch(srv.fileno(), GLib.IO_IN, on_connect)
    if first:
        on_event(first)
    else:
        schedule()
    try:
        loop.run()
    finally:
        srv.close()
        if os.path.exists(path):
            os.unlink(path)


if __name__ == "__main__":
    try:
        main()
    except BaseException as e:  # a daemon must never leave a traceback anywhere but the log
        log("daemon: %s" % type(e).__name__)
