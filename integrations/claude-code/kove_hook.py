#!/usr/bin/env python3
"""Thin Claude Code hook client (D-49): never prints, never fails, returns fast. Run as `python3 -S`."""
import json
import os
import socket
import sys

KEEP = ("session_id", "cwd", "hook_event_name", "tool_name", "tool_input", "notification_type", "message",
        "task_id", "task_subject", "last_assistant_message")


def sock_path(session_id):
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return os.path.join(base, "kove-claude", "".join(c for c in session_id if c.isalnum() or c in "-_") + ".sock")


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


def main():
    ev = json.load(sys.stdin)
    msg = {k: ev[k] for k in KEEP if k in ev}
    if "tool_input" in msg:
        msg["tool_input"] = tool_input_slim(msg["tool_input"])
    if "last_assistant_message" in msg:  # the daemon only shows the first sentence
        msg["last_assistant_message"] = str(msg["last_assistant_message"])[:600]
    data = json.dumps(msg).encode()
    path = sock_path(msg["session_id"])
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(1)
        s.connect(path)
        s.sendall(data)
        s.close()
    except OSError:
        if msg.get("hook_event_name") == "UserPromptSubmit":
            import subprocess  # only on the spawn path: 3 ms off every other hook call
            here = os.path.dirname(os.path.abspath(__file__))
            p = subprocess.Popen([sys.executable, os.path.join(here, "kove_daemon.py")], stdin=subprocess.PIPE,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            p.stdin.write(data)
            p.stdin.close()


if __name__ == "__main__":
    try:
        main()
    except BaseException as e:
        log("hook: %r" % e)
    sys.exit(0)
