#!/usr/bin/env python3
"""Soak driver for the agent aggregator (D-58, D-60): a fake Claude Code session sends real hook events through the installed
kove_hook.py for N minutes, plus status-line payloads through kove_statusline.py once a second (a realistic render rate while
a session works; the helper itself dedupes and throttles, and the cost, lines, context and usage drift slowly), and every 5 minutes the CPU (average over the window) and RSS of plasmashell and the aggregator
plus the aggregator log size are appended to a CSV. No real Claude, no media, no notifications (no permission prompts).
  scripts/agent-soak.py [minutes=60] [csv]"""
import json, os, random, subprocess, sys, threading, time

MIN = float(sys.argv[1]) if len(sys.argv) > 1 else 60
CSV = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/os_setup/perf/results/w21-soak.csv")
HOOK = os.path.expanduser("~/.local/share/kove/claude-code/kove_hook.py")
STATUSLINE = os.path.expanduser("~/.local/share/kove/claude-code/kove_statusline.py")
LOG = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "kove", "claude-code.log")
SID, CWD = "soak-fake", "/tmp/kove-soak"
TICK = os.sysconf("SC_CLK_TCK")
END = time.time() + MIN * 60
n = [0]


def send(kind, **kw):
    ev = dict(hook_event_name=kind, session_id=SID, cwd=CWD, **kw)
    subprocess.run([sys.executable, "-S", HOOK], input=json.dumps(ev).encode(), timeout=10)


def tool(name, ti, secs):
    n[0] += 1
    tid = "t%d" % n[0]
    send("PreToolUse", tool_name=name, tool_input=ti, tool_use_id=tid)
    time.sleep(secs)
    send("PostToolUse", tool_name=name, tool_input=ti, tool_use_id=tid)


def todos(done):
    return [{"content": "step %d" % i, "status": "completed" if i < done else "in_progress" if i == done else "pending"} for i in range(7)]


def drive():
    send("UserPromptSubmit")
    last_sleep = last_sub = last_todo = last_turn = time.time()
    done, subs = 0, []
    while time.time() < END:
        now = time.time()
        if now - last_sleep > 600:
            last_sleep = now
            tool("Bash", {"command": "sleep 60"}, 60)
        if now - last_sub > 180:
            last_sub = now
            aid = "sub%d" % n[0]
            send("SubagentStart", agent_id=aid, agent_type=random.choice(["Explore", "Plan", "general-purpose"]))
            subs.append((now + random.uniform(30, 90), aid))
        for item in [s for s in subs if s[0] < now]:
            subs.remove(item)
            send("SubagentStop", agent_id=item[1], agent_type="Explore")
        if now - last_todo > 120:
            last_todo, done = now, (done + 1) % 8
            tool("TodoWrite", {"todos": todos(done)}, 0.2)
        if now - last_turn > 900:
            last_turn = now
            send("Stop")
            time.sleep(12)  # past the done linger
            send("UserPromptSubmit")
        tool(*random.choice([("Bash", {"command": "make build"}, 1.5), ("Edit", {"file_path": "/tmp/a.qml"}, 0.5),
                             ("Read", {"file_path": "/tmp/b.qml"}, 0.3), ("Grep", {}, 0.4)]))
        time.sleep(random.uniform(2, 5))
    send("SessionEnd")


def render():
    """One status-line render per second. Values change every few renders, as they do while a session works."""
    k = 0
    while time.time() < END:
        k += 1
        payload = {"session_id": SID, "cwd": CWD, "transcript_path": "/tmp/x.jsonl",
                   "rate_limits": {"five_hour": {"used_percentage": 20 + k // 600 % 60, "resets_at": int(time.time()) + 3 * 3600},
                                   "seven_day": {"used_percentage": 10 + k // 3000 % 80, "resets_at": int(time.time()) + 3 * 86400}},
                   "context_window": {"used_percentage": k // 20 % 90},
                   "cost": {"total_cost_usd": k * 0.0007, "total_lines_added": k // 15, "total_lines_removed": k // 60}}
        subprocess.run([sys.executable, "-S", STATUSLINE], input=json.dumps(payload).encode(), timeout=10)
        time.sleep(1)


def pid_of(match):
    for p in os.listdir("/proc"):
        if p.isdigit():
            try:
                cmd = open("/proc/%s/cmdline" % p).read()
            except OSError:
                continue
            if match in cmd and "agent-soak" not in cmd:
                return int(p)


def stat(pid):
    try:
        f = open("/proc/%d/stat" % pid).read().rsplit(")", 1)[1].split()
        rss = int(open("/proc/%d/statm" % pid).read().split()[1]) * os.sysconf("SC_PAGE_SIZE") / 1e6
        return (int(f[11]) + int(f[12])) / TICK, rss
    except (OSError, IndexError, TypeError):
        return None, None


def sample():
    os.makedirs(os.path.dirname(CSV), exist_ok=True)
    out = open(CSV, "w", buffering=1)
    out.write("minute,plasmashell_cpu_pct,plasmashell_rss_mb,aggregator_cpu_pct,aggregator_rss_mb,log_bytes\n")
    t0 = time.time()
    prev = {}
    k = 0
    while time.time() < END + 5:
        time.sleep(300 if k else 20)
        row = []
        for name, match in (("ps", "plasmashell"), ("agg", "kove_daemon.py")):
            pid = pid_of(match)
            cpu, rss = stat(pid) if pid else (None, None)
            was = prev.get(name)
            pct = "" if cpu is None or not was or was[0] != pid else "%.2f" % (100 * (cpu - was[1]) / (time.time() - was[2]))
            prev[name] = (pid, cpu, time.time())
            row += [pct, "" if rss is None else "%.1f" % rss]
        size = os.path.getsize(LOG) if os.path.exists(LOG) else 0
        out.write("%.0f,%s,%d\n" % ((time.time() - t0) / 60, ",".join(row), size))
        k += 1


if __name__ == "__main__":
    threading.Thread(target=sample, daemon=True).start()
    threading.Thread(target=render, daemon=True).start()
    drive()
    time.sleep(310)  # one last sample after the session ends
