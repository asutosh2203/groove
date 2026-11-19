#!/usr/bin/env python3
"""Thin Claude Code hook client (D-49): never prints, never fails, returns fast. Run as `python3 -S`."""
import json
import os
import socket
import sys

SPAWN_ON = ("SessionStart", "UserPromptSubmit")
KEEP = ("session_id", "cwd", "hook_event_name", "tool_name", "tool_input", "notification_type", "message",
        "task_id", "task_subject", "tool_use_id", "agent_id", "agent_type", "last_assistant_message")


FLATPAK_INFO = os.environ.get("KOVE_FLATPAK_INFO", "/.flatpak-info")  # overridable so tests can fake a sandbox


def sock_path():
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "kove", "agents.sock")


WINDOWS = (("five_hour", "fiveHour"), ("seven_day", "sevenDay"))


def _num(v):
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) and v == v and abs(v) != float("inf") else None


def usage_windows(p):
    """The limit windows of a payload's `rate_limits` -> {fiveHour|sevenDay: {pct, resetsAt}}; absent or malformed windows are
    simply absent. Numbers only: the one place usage is read, for the status line and for any hook payload that carries it."""
    limits = p.get("rate_limits") if isinstance(p, dict) and isinstance(p.get("rate_limits"), dict) else {}
    out = {}
    for src, dst in WINDOWS:
        w = limits.get(src) if isinstance(limits.get(src), dict) else {}
        pct, at = _num(w.get("used_percentage")), _num(w.get("resets_at"))
        if pct is not None and at is not None and at > 0:
            out[dst] = {"pct": max(0, min(100, round(pct))), "resetsAt": int(at)}
    return out


def log(msg):
    try:
        d = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "kove")
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, "claude-code.log")
        if os.path.exists(p) and os.path.getsize(p) > 100000:
            os.replace(p, p + ".1")
        with open(p, "a") as f:
            f.write(msg[:500] + "\n")
    except Exception:
        pass


def tool_input_slim(ti):
    # Only what status text and progress need: no file contents, commands beyond the test match, or prompts.
    if not isinstance(ti, dict):
        return {}
    out = {k: ti[k] for k in ("file_path", "notebook_path", "taskId", "status") if k in ti}
    if "command" in ti:
        out["command"] = str(ti["command"])[:200]
    if isinstance(ti.get("todos"), list):
        out["todos"] = [{"content": str(t.get("content", ""))[:80], "status": t.get("status")}
                        for t in ti["todos"] if isinstance(t, dict)]
    return out


def ancestors(pid, proc="/proc"):
    """Claude Code's process chain upwards, so Kove can find the window that hosts it. Pids only, no names.
    Stops before the systemd --user manager: it hosts every app, so it identifies none."""
    chain = []
    while pid > 1 and len(chain) < 32:
        with open("%s/%d/stat" % (proc, pid)) as f:
            stat = f.read()
        if stat[stat.index("(") + 1:stat.rindex(")")] == "systemd":
            break
        chain.append(pid)
        pid = int(stat.rsplit(")", 1)[1].split()[1])
    return chain


def where():
    ppid = os.getppid()
    try:
        scope = open("/proc/%d/cgroup" % ppid).read().strip().rsplit("/", 1)[-1]
    except OSError:
        scope = ""
    try:
        return ancestors(ppid), scope
    except (OSError, ValueError, IndexError):
        return [ppid], scope


def main():
    ev = json.load(sys.stdin)
    msg = {k: ev[k] for k in KEEP if k in ev}
    if "tool_input" in msg:
        msg["tool_input"] = tool_input_slim(msg["tool_input"])
    if "last_assistant_message" in msg:  # only the first sentence is shown
        msg["last_assistant_message"] = str(msg["last_assistant_message"])[:600]
    usage = usage_windows(ev)
    if usage:  # not in Claude Code's hook payloads today; a future one that carries rate_limits reports with no change here
        msg["usage"] = usage
    if msg.get("hook_event_name") in SPAWN_ON:
        msg["pids"], msg["scope"] = where()
    data = json.dumps(msg).encode()
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(1)
        s.connect(sock_path())
        s.sendall(data)
        s.close()
    except OSError:
        if msg.get("hook_event_name") not in SPAWN_ON:
            return
        if os.path.exists(FLATPAK_INFO):  # a sandbox must not start host processes
            hint_once()
            return
        import subprocess  # only on the spawn path: 3 ms off every other hook call
        here = os.path.dirname(os.path.abspath(__file__))
        p = subprocess.Popen([sys.executable, os.path.join(here, "kove_daemon.py")], stdin=subprocess.PIPE,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        p.stdin.write(data)
        p.stdin.close()


def hint_once():
    flag = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "kove", "flatpak-hint")
    if not os.path.exists(flag):
        log("sandboxed: Kove is not running or the socket is hidden; see the README (flatpak override --filesystem=xdg-run/kove)")
        try:
            open(flag, "w").close()
        except OSError:
            pass


if __name__ == "__main__":
    try:
        main()
    except BaseException as e:
        log("hook: %s" % type(e).__name__)
    sys.exit(0)
