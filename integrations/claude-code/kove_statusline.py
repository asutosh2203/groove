#!/usr/bin/env python3
"""Claude Code status-line helper (D-60): forwards usage numbers to the aggregator, then runs the user's original
status line unchanged. Runs on every render, so it stays tiny: `python3 -S`, never prints on its own, never fails.
Only usage, context %, cost and line counts leave this process: no transcript path, cwd or content."""
import json
import os
import socket
import sys
import time

from kove_hook import log, sock_path

MIN_INTERVAL = 2.0  # seconds between reports of one session
WINDOWS = (("five_hour", "fiveHour"), ("seven_day", "sevenDay"))
HERE = os.path.dirname(os.path.abspath(__file__))


def _num(v):
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) and v == v and abs(v) != float("inf") else None


def extract(p):
    """Payload -> the message for the aggregator, or None when it has no session id."""
    if not isinstance(p, dict) or not isinstance(p.get("session_id"), str) or not p["session_id"]:
        return None
    msg = {"hook_event_name": "StatusLine", "session_id": p["session_id"][:128]}
    limits = p.get("rate_limits") if isinstance(p.get("rate_limits"), dict) else {}
    usage = {}
    for src, dst in WINDOWS:
        w = limits.get(src) if isinstance(limits.get(src), dict) else {}
        pct, at = _num(w.get("used_percentage")), _num(w.get("resets_at"))
        if pct is not None and at is not None and at > 0:
            usage[dst] = {"pct": max(0, min(100, round(pct))), "resetsAt": int(at)}
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


def state_dir():
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "kove")


def state_file(sid):
    import hashlib
    return os.path.join(state_dir(), "sl-" + hashlib.sha1(sid.encode()).hexdigest()[:16])


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
    tmp = "%s.%d.tmp" % (state_path, os.getpid())
    with open(tmp, "w") as f:
        json.dump({"key": key, "at": now}, f)
    os.replace(tmp, state_path)
    return True


def prune(max_age=86400):
    """Session state files older than a day (runtime dirs are cleared at logout; this covers long sessions)."""
    d, cutoff = state_dir(), time.time() - max_age
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
        if msg and should_send(msg, time.time(), state_file(msg["session_id"])):
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
