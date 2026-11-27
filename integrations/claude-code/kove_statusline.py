#!/usr/bin/env python3
"""Claude Code status-line helper (D-60): forwards usage numbers to the aggregator, then runs the user's original
status line unchanged. Runs on every render, so it stays tiny: `python3 -S`, never prints on its own, never fails.
Only usage, context %, cost and line counts leave this process: no transcript path, cwd or content."""
import json
import os
import socket
import sys
import time

from kove_hook import NO_RUNTIME, _num, hint_once, log, runtime_dir, sock_path, usage_windows

MIN_INTERVAL = 2.0  # seconds between reports of one session
HERE = os.path.dirname(os.path.abspath(__file__))


def extract(p):
    """Payload -> the message for the aggregator, or None when it has no session id."""
    if not isinstance(p, dict) or not isinstance(p.get("session_id"), str) or not p["session_id"]:
        return None
    msg = {"hook_event_name": "StatusLine", "session_id": p["session_id"][:128]}
    usage = usage_windows(p)
    if usage:
        msg["usage"] = usage
    ctx = p.get("context_window") if isinstance(p.get("context_window"), dict) else {}
    pct = _num(ctx.get("used_percentage"))
    msg["contextPct"] = None if pct is None else max(0, min(100, round(pct)))  # null clears: early on or after /compact
    cost = p.get("cost") if isinstance(p.get("cost"), dict) else {}
    usd = _num(cost.get("total_cost_usd"))
    msg["costUsd"] = round(max(0, usd), 2) if usd is not None else 0
    for src, dst in (("total_lines_added", "linesAdded"), ("total_lines_removed", "linesRemoved")):
        n = _num(cost.get(src))
        msg[dst] = int(max(0, n)) if n is not None else 0
    return msg


def state_file(sid):
    """None without XDG_RUNTIME_DIR: then nothing is recorded or sent."""
    import hashlib
    d = runtime_dir()
    return os.path.join(d, "sl-" + hashlib.sha1(sid.encode()).hexdigest()[:16]) if d else None


def should_send(msg, now, state_path):
    """Changed values, at most once per MIN_INTERVAL, per session. Records the report when it says yes.
    The state is one file per session, replaced atomically, so two renders racing cannot corrupt it."""
    key = json.dumps({k: v for k, v in msg.items() if k != "hook_event_name"}, sort_keys=True)
    new_session = False
    try:
        with open(state_path) as f:
            old = json.load(f)
        if old["key"] == key or now - old["at"] < MIN_INTERVAL:
            return False
    except (OSError, ValueError, KeyError, TypeError):
        new_session = True
    d = os.path.dirname(state_path)
    os.makedirs(d, mode=0o700, exist_ok=True)
    if new_session:
        try:
            prune()
        except OSError:
            pass
    import tempfile  # only when writing: it costs about 10 ms to import, every render would pay it
    fd, tmp = tempfile.mkstemp(dir=d, prefix=os.path.basename(state_path) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump({"key": key, "at": now}, f)
        os.replace(tmp, state_path)
    except BaseException:
        os.unlink(tmp)
        raise
    return True


def prune(max_age=86400):
    """Session state files older than a day (runtime dirs are cleared at logout; this covers long sessions)."""
    d, cutoff = runtime_dir(), time.time() - max_age
    for n in os.listdir(d):
        p = os.path.join(d, n)
        if n.startswith("sl-") and os.path.getmtime(p) < cutoff:
            os.unlink(p)


def forward(msg):
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(1)
    s.connect(sock_path())
    s.sendall(json.dumps(msg).encode())
    s.close()


def original_command(path=None):
    """The status line that was configured before Kove's (saved by install.sh), or None."""
    try:
        with open(path or os.path.join(HERE, "statusline-original.json")) as f:
            o = json.load(f)
        return o["command"] if o.get("type", "command") == "command" and o.get("command") else None
    except (OSError, ValueError, KeyError, AttributeError):
        return None


def main():
    raw = sys.stdin.buffer.read()
    try:
        msg = extract(json.loads(raw))
        path = state_file(msg["session_id"]) if msg else None
        if msg and path is None:
            hint_once(*NO_RUNTIME)
        elif msg and should_send(msg, time.time(), path):
            forward(msg)
    except OSError:
        pass  # no aggregator: nothing listens, the hooks start it
    except Exception as e:
        log("statusline: %s" % type(e).__name__)
    cmd = original_command()
    if not cmd:
        return 0
    import subprocess  # only when chaining
    # As Claude Code runs it: through the shell, same environment and cwd, the raw payload on stdin, no timeout. Its
    # output goes straight to ours; its exit status is ours.
    return subprocess.run(cmd, shell=True, input=raw).returncode


if __name__ == "__main__":
    try:
        code = main()
    except BaseException as e:
        log("statusline: %s" % type(e).__name__)
        code = 0
    sys.exit(code)
