#!/usr/bin/env python3
"""Per-session helper: owns the KDE job (its lifetime is this D-Bus connection) and sends notifications (D-49).
First event arrives on stdin from the spawning hook; later ones over the Unix socket."""
import json
import os
import socket
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kove_logic as L
from kove_hook import log, sock_path



def _installed(entry):
    dirs = [os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")]
    dirs += (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return any(os.path.exists(os.path.join(d, "applications", entry + ".desktop")) for d in dirs)


DESKTOP_ENTRY = L.pick_entry(os.environ.get("KOVE_CLAUDE_DESKTOP_ENTRY", ""), _installed)
L.IDLE_TIMEOUT = float(os.environ.get("KOVE_CLAUDE_IDLE_SECONDS", L.IDLE_TIMEOUT))
JOBS = os.environ.get("KOVE_CLAUDE_JOBS") == "1"  # off by default: plasmashell can crash on rapid job churn (D-49)
DONE_MIN = float(os.environ.get("KOVE_CLAUDE_DONE_MIN_SECONDS", "30"))


class Kde:
    """Notifications always; the job only with KOVE_CLAUDE_JOBS=1 and never within the cooldown of any job's end."""

    def __init__(self, title):
        import dbus
        self.dbus = dbus
        self.bus = dbus.SessionBus()
        self.notes = dbus.Interface(self.bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"),
                                    "org.freedesktop.Notifications")
        self.title, self.job, self.suspended, self.percent = title, None, None, None

    def _ensure_job(self):
        if self.job is not None:
            return True
        if not JOBS or L.cooldown_remaining(read_last_end(), time.time()) > 0:
            return False  # tried again on the next update
        d = self.dbus
        server = d.Interface(self.bus.get_object("org.kde.kuiserver", "/JobViewServer"), "org.kde.JobViewServerV2")
        path = server.requestView(DESKTOP_ENTRY, 0, {})  # first arg is the desktop file, not a title
        self.job = d.Interface(self.bus.get_object("org.kde.kuiserver", path), "org.kde.JobViewV2")
        self.job.setInfoMessage(self.title)
        self.suspended = self.percent = None
        return True

    def apply(self, a):
        d = self.dbus
        if a["op"] == "notify":
            hints = {"desktop-entry": DESKTOP_ENTRY, "urgency": d.Byte(2 if a["urgent"] else 1)}
            self.notes.Notify("Claude Code", d.UInt32(0), "", a["summary"], a["body"], [], hints, -1)
        elif a["op"] == "job" and self._ensure_job():
            if a["percent"] is not None and a["percent"] != self.percent:
                self.job.setPercent(d.UInt32(a["percent"]))
                self.percent = a["percent"]
            self.job.setInfoMessage("%s · %s" % (self.title, a["info"]))
            if a["suspended"] != self.suspended:
                self.job.setSuspended(a["suspended"])
                self.suspended = a["suspended"]
        elif a["op"] == "end" and self.job is not None:
            self.job.terminate("")
            self.job = None
            write_last_end(time.time())


def _stamp():
    return os.path.join(os.path.dirname(sock_path("x")), "last-job-end")


def read_last_end():
    try:
        return float(open(_stamp()).read())
    except (OSError, ValueError):
        return None


def write_last_end(t):
    try:
        with open(_stamp(), "w") as f:
            f.write(repr(t))
    except OSError as e:
        log("stamp: %r" % e)


def main():
    first = json.loads(sys.stdin.read())
    path = sock_path(first["session_id"])
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    if os.path.exists(path):
        os.unlink(path)
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(path)
    os.chmod(path, 0o600)
    srv.listen(8)
    try:
        run = L.Run(first.get("cwd"), time.time(), DONE_MIN)
        kde = Kde("Claude · " + run.project)
        events = [first]
        srv.settimeout(1)
        while not run.ended:
            for ev in events:
                for a in run.handle(ev, time.time()):
                    kde.apply(a)
            events = []
            while not events and not run.ended:
                if run.expired(time.time()):
                    kde.apply({"op": "end"})
                    return
                try:
                    conn, _ = srv.accept()
                except socket.timeout:
                    continue
                with conn:
                    conn.settimeout(1)
                    data = b""
                    while chunk := conn.recv(65536):
                        data += chunk
                    events.append(json.loads(data))
    finally:
        srv.close()
        if os.path.exists(path):
            os.unlink(path)


if __name__ == "__main__":
    try:
        main()
    except BaseException as e:  # a daemon must never leave a traceback anywhere but the log
        log("daemon: %r" % e)
