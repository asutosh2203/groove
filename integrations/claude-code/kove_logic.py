"""Pure decisions for the Claude Code -> Kove bridge: no I/O, no D-Bus (D-49, D-57). The aggregator executes them."""
import os
import re

IDLE_TIMEOUT = 600  # seconds of silence before a crashed session is dropped
DONE_LINGER = 10  # a finished session stays in the snapshot this long, then Kove fades it
PROTOCOL = 1
AGENT_ID, AGENT_NAME = "claude-code", "Claude Code"

_TOOL_STATUS = {
    "Edit": "Editing {f}", "MultiEdit": "Editing {f}", "Write": "Writing {f}", "NotebookEdit": "Editing {f}",
    "Read": "Reading {f}", "Glob": "Searching files", "Grep": "Searching code",
    "WebSearch": "Searching the web", "WebFetch": "Fetching a page",
    "Agent": "Running a subagent", "Task": "Running a subagent",
}
_TOOL_ACTION = {"Edit": "edit", "MultiEdit": "edit", "Write": "edit", "NotebookEdit": "edit", "Read": "read",
                "Glob": "search", "Grep": "search", "WebSearch": "search", "WebFetch": "read"}
_TEST_RE = re.compile(r"\b(pytest|unittest|jest|vitest|mocha|cargo test|go test|npm (run )?test|qmltestrunner|node --test|check-qml)\b")
_SCOPE_RE = re.compile(r"^app-(.+?)(?:-\d+)?\.scope$")


def project_name(cwd, exists=os.path.exists):
    """Basename of the git root (a .git folder or, in a worktree, a file) above cwd; the cwd's own basename otherwise."""
    cwd = (cwd or "").rstrip("/")
    d = cwd
    while d and d != "/":
        if exists(os.path.join(d, ".git")):
            return os.path.basename(d)
        d = os.path.dirname(d)
    return os.path.basename(cwd) or "project"


def status_for_tool(name, tool_input):
    tool_input = tool_input if isinstance(tool_input, dict) else {}
    if name == "Bash":
        return "Running tests" if _TEST_RE.search(str(tool_input.get("command", ""))) else "Running a command"
    template = _TOOL_STATUS.get(name)
    if template is None:
        return "Working"
    path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    return template.format(f=os.path.basename(path) or "a file")


def first_sentence(text, cap=80):
    """Markdown and code stripped, first sentence, capped. Nothing else of the message is kept."""
    text = re.sub(r"```.*?```", " ", str(text or ""), flags=re.S)
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"(?m)^\s*(#+|[-*>]|\d+\.)\s+", "", text)
    text = re.sub(r"[*_~]{1,3}", "", text)
    text = " ".join(text.split())
    m = re.search(r"[.!?](\s|$)", text)
    if m:
        text = text[:m.start() + 1]
    return text if len(text) <= cap else text[:cap - 1].rstrip() + "…"


def _target_path(tool_input):
    return os.path.basename(tool_input.get("file_path") or tool_input.get("notebook_path") or "")


def action_for_tool(name, tool_input):
    """-> (action, short target): edit|run|read|search|other. The target is a file name or a command's first words."""
    tool_input = tool_input if isinstance(tool_input, dict) else {}
    if name == "Bash":
        return "run", " ".join(str(tool_input.get("command", "")).split()[:4])[:40]
    return _TOOL_ACTION.get(name, "other"), _target_path(tool_input)


def waiting_command(name, tool_input):
    tool_input = tool_input if isinstance(tool_input, dict) else {}
    if name == "Bash":
        return " ".join(str(tool_input.get("command", "")).split())[:80]
    return status_for_tool(name, tool_input)


def scope_app_id(segment):
    """'app-com.microsoft.VSCode-3386.scope' -> 'com.microsoft.VSCode'; 'app-flatpak-<id>-N.scope' and
    'app-<launcher>-<id>-N.scope' -> '<id>'. Anything else (a Konsole 'tab(N).scope') -> ''."""
    m = _SCOPE_RE.match(segment or "")
    if not m:
        return ""
    launcher = re.match(r"^\w+-(.+)$", m.group(1))  # a launcher prefix has no dot; a dashed app id like org.x.my-app keeps its dash
    return launcher.group(1) if launcher else m.group(1)


def task_counts(tasks):
    """tasks: ordered {id: {"subject", "status"}} -> (done, total, current subject)."""
    done = sum(1 for t in tasks.values() if t["status"] == "completed")
    current = next((t["subject"] for t in tasks.values() if t["status"] == "in_progress"), "")
    return done, len(tasks), current


def done_ping(elapsed, min_seconds):
    return elapsed >= min_seconds


class Session:
    """One Claude Code session: working | waiting | done. handle() returns notification actions only."""

    def __init__(self, sid, cwd, now, done_min=30):
        self.sid, self.project, self.done_min = sid, project_name(cwd), done_min
        self.pids, self.scope_app = [], ""
        self._reset(now)

    def _reset(self, now):
        self.state = "working"
        self.started = self.updated = now
        self.tasks = {}
        self.action = self.target = self.waiting_cmd = self.last_message = ""
        self.done_until = None

    def expired(self, now):
        if self.state == "done":
            return now >= self.done_until
        return self.state != "waiting" and now - self.updated > IDLE_TIMEOUT

    def _task_events(self, name, ti):
        if name == "TodoWrite":
            self.tasks = {str(i): {"subject": t.get("content", ""), "status": t.get("status", "pending")}
                          for i, t in enumerate(ti.get("todos") or []) if isinstance(t, dict)}
        elif name == "TaskUpdate" and str(ti.get("taskId")) in self.tasks and ti.get("status"):
            self.tasks[str(ti["taskId"])]["status"] = ti["status"]

    def handle(self, ev, now):
        kind = ev.get("hook_event_name")
        if kind == "UserPromptSubmit":
            self._reset(now)
            return []
        if self.state == "done":  # stragglers between Stop and the linger's end change nothing
            return []
        self.updated = now
        if self.state == "waiting":  # any event after a prompt means it was answered
            self.state, self.waiting_cmd = "working", ""
        tool, ti = ev.get("tool_name"), ev.get("tool_input") if isinstance(ev.get("tool_input"), dict) else {}
        if kind == "PermissionRequest":
            self.state, self.waiting_cmd = "waiting", waiting_command(tool, ti)
            return [{"op": "notify", "urgent": True, "summary": self.project + " · Needs your OK",
                     "body": status_for_tool(tool, ti), "sid": self.sid}]
        if kind == "Notification" and ev.get("notification_type") in ("idle_prompt", "elicitation_dialog"):
            self.state, self.waiting_cmd = "waiting", str(ev.get("message") or "")[:80]
            return [{"op": "notify", "urgent": True, "summary": self.project + " · Needs your OK",
                     "body": str(ev.get("message") or "")[:120], "sid": self.sid}]
        if kind == "PreToolUse":
            self.action, self.target = action_for_tool(tool, ti)
            self._task_events(tool, ti)
        elif kind == "TaskCreated":
            self.tasks[str(ev.get("task_id"))] = {"subject": ev.get("task_subject", ""), "status": "pending"}
        elif kind == "TaskCompleted" and str(ev.get("task_id")) in self.tasks:
            self.tasks[str(ev.get("task_id"))]["status"] = "completed"
        elif kind == "Stop":
            self.state, self.done_until = "done", now + DONE_LINGER
            self.last_message = first_sentence(ev.get("last_assistant_message"))
            if done_ping(now - self.started, self.done_min) and self.last_message:
                return [{"op": "notify", "urgent": False, "summary": self.project + " · " + self.last_message, "body": "", "sid": self.sid}]
        return []

    def to_dict(self):
        done, total, current = task_counts(self.tasks)
        d = {"id": self.sid, "agent": AGENT_ID, "name": AGENT_NAME, "project": self.project, "pids": self.pids,
             "scopeApp": self.scope_app, "state": self.state, "task": current, "done": done, "total": total,
             "action": self.action, "target": self.target, "waitingCommand": self.waiting_cmd,
             "startedAt": int(self.started), "updatedAt": int(self.updated)}
        if self.state == "done":
            d["lastMessage"] = self.last_message
        return d


class Hub:
    """All sessions of this user. handle() returns notification actions; snapshot() is what Kove reads."""

    def __init__(self, done_min=30):
        self.sessions, self.done_min, self.empty_since = {}, done_min, None

    def handle(self, ev, now):
        sid, kind = ev.get("session_id"), ev.get("hook_event_name")
        if not sid or kind == "SessionStart":  # a session only exists once it does something
            return []
        if kind == "SessionEnd":
            self.sessions.pop(sid, None)
            return []
        s = self.sessions.get(sid)
        if s is None:
            s = self.sessions[sid] = Session(sid, ev.get("cwd"), now, self.done_min)
        if ev.get("pids") and not s.pids:
            s.pids, s.scope_app = [int(p) for p in ev["pids"]][:32], scope_app_id(ev.get("scope", ""))
        return s.handle(ev, now)

    def tick(self, now):
        """Drops expired sessions. -> True when the snapshot changed."""
        gone = [k for k, s in self.sessions.items() if s.expired(now)]
        for k in gone:
            del self.sessions[k]
        return bool(gone)

    def idle_for(self, now):
        if self.sessions:
            self.empty_since = None
        elif self.empty_since is None:
            self.empty_since = now
        return 0 if self.empty_since is None else now - self.empty_since

    def snapshot(self):
        return {"v": PROTOCOL, "sessions": [s.to_dict() for s in sorted(self.sessions.values(), key=lambda s: s.started)]}


class Routes:
    """Notification id -> session id, so a click on the notification raises that session's window (D-57). Bounded."""

    def __init__(self, cap=64):
        self.cap, self.ids = cap, {}

    def remember(self, nid, sid):
        self.ids.pop(nid, None)
        self.ids[nid] = sid
        while len(self.ids) > self.cap:
            del self.ids[next(iter(self.ids))]

    def session_for(self, nid, key):
        """Only the default action (a click on the body) raises; other actions and unknown ids do nothing."""
        return self.ids.get(nid) if key == "default" else None


def ingest(hub, data, now, log):
    """Bytes from a hook -> notification actions. A bad payload logs the error type only, never its content."""
    import json
    try:
        ev = json.loads(data)
        return hub.handle(ev, now) if isinstance(ev, dict) else []
    except Exception as e:
        log("ingest: %s" % type(e).__name__)
        return []
