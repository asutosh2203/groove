"""Pure decisions for the Claude Code -> Kove bridge: no I/O, no D-Bus (D-49). The daemon executes the actions."""
import os
import re
import time

IDLE_TIMEOUT = 600  # seconds of silence before a crashed session's job is ended
GRACE = 10  # after Stop the job lingers, so a quick next prompt reuses it (D-49: terminate+create in a row crashes plasmashell)

_TOOL_STATUS = {
    "Edit": "Editing {f}", "MultiEdit": "Editing {f}", "Write": "Writing {f}", "NotebookEdit": "Editing {f}",
    "Read": "Reading {f}", "Glob": "Searching files", "Grep": "Searching code",
    "WebSearch": "Searching the web", "WebFetch": "Fetching a page",
    "Agent": "Running a subagent", "Task": "Running a subagent",
}
_TEST_RE = re.compile(r"\b(pytest|unittest|jest|vitest|mocha|cargo test|go test|npm (run )?test|qmltestrunner|node --test|check-qml)\b")

JOB_COOLDOWN = 5  # no job is created this soon after any job ended, in any session (D-49)


def cooldown_remaining(last_end, now, cooldown=JOB_COOLDOWN):
    if last_end is None:
        return 0.0
    return min(cooldown, max(0.0, last_end + cooldown - now))  # the min also covers a timestamp from a skewed clock


def project_name(cwd):
    return os.path.basename((cwd or "").rstrip("/")) or "project"


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


def progress(tasks):
    """tasks: ordered {id: {"subject", "status"}}. -> (percent or None, status line or None)."""
    total = len(tasks)
    if not total:
        return None, None
    done = sum(1 for t in tasks.values() if t["status"] == "completed")
    current = next((t["subject"] for t in tasks.values() if t["status"] == "in_progress"), "")
    line = "%d of %d" % (done, total) + (" · " + current if current else "")
    return done * 100 // total, line


def done_ping(elapsed, min_seconds):
    return elapsed >= min_seconds


class Run:
    """One daemon's lifetime: runs (prompt -> Stop) reusing one job. handle() returns actions; waiting freezes the idle
    timeout; after Stop the job idles for GRACE seconds and a new prompt resets it instead of creating another."""

    def __init__(self, cwd, now, done_min=30):
        self.project = project_name(cwd)
        self.done_min = done_min
        self.ended = False
        self.grace_until = None
        self._reset(now)

    def _reset(self, now):
        self.started = self.last_event = now
        self.tasks = {}
        self.status = "Working"
        self.waiting = False
        self.grace_until = None

    def expired(self, now):
        if self.grace_until is not None:
            return now >= self.grace_until
        return not self.waiting and now - self.last_event > IDLE_TIMEOUT

    def _job(self, percent=False):
        pct, line = progress(self.tasks)
        return {"op": "job", "percent": 0 if percent else pct, "info": line or self.status, "suspended": self.waiting}

    def _task_events(self, name, ti):
        if name == "TodoWrite":
            self.tasks = {str(i): {"subject": t.get("content", ""), "status": t.get("status", "pending")}
                          for i, t in enumerate(ti.get("todos") or []) if isinstance(t, dict)}
        elif name == "TaskUpdate" and str(ti.get("taskId")) in self.tasks and ti.get("status"):
            self.tasks[str(ti["taskId"])]["status"] = ti["status"]

    def handle(self, ev, now):
        kind = ev.get("hook_event_name")
        if kind == "SessionEnd":
            self.ended = True
            return [{"op": "end"}]
        if kind == "UserPromptSubmit" and self.grace_until is not None:
            self._reset(now)
            return [self._job(percent=True)]
        if self.grace_until is not None:  # stragglers between Stop and the grace expiry change nothing
            return []
        self.last_event = now
        if self.waiting:  # any event after a prompt means it was answered
            self.status = "Working"
        self.waiting = False
        out = []
        if kind == "PermissionRequest":
            self.waiting, self.status = True, "Needs your OK"
            out.append({"op": "notify", "urgent": True, "summary": self.project + " · Needs your OK",
                        "body": status_for_tool(ev.get("tool_name"), ev.get("tool_input"))})
        elif kind == "Notification" and ev.get("notification_type") in ("idle_prompt", "elicitation_dialog"):
            self.waiting, self.status = True, "Needs your input"
            out.append({"op": "notify", "urgent": True, "summary": self.project + " · Needs your OK",
                        "body": str(ev.get("message") or "")[:120]})
        elif kind == "PreToolUse":
            self.status = status_for_tool(ev.get("tool_name"), ev.get("tool_input"))
            self._task_events(ev.get("tool_name"), ev.get("tool_input") if isinstance(ev.get("tool_input"), dict) else {})
        elif kind == "TaskCreated":
            self.tasks[str(ev.get("task_id"))] = {"subject": ev.get("task_subject", ""), "status": "pending"}
        elif kind == "TaskCompleted" and str(ev.get("task_id")) in self.tasks:
            self.tasks[str(ev.get("task_id"))]["status"] = "completed"
        elif kind == "Stop":
            self.grace_until = now + GRACE
            sentence = first_sentence(ev.get("last_assistant_message")) if done_ping(now - self.started, self.done_min) else ""
            if sentence:
                out.append({"op": "notify", "urgent": False, "summary": self.project + " · " + sentence, "body": ""})
            return out + [{"op": "job", "percent": 100, "info": "Done", "suspended": False}]
        out.append(self._job())
        return out


CANDIDATE_ENTRIES = ("com.microsoft.VSCode", "code", "code-oss", "visual-studio-code", "org.kde.konsole")


def pick_entry(preferred, exists):
    """The configured entry if it is installed, else the first installed candidate, else the last (a terminal)."""
    for e in ([preferred] if preferred else []) + list(CANDIDATE_ENTRIES):
        if exists(e):
            return e
    return CANDIDATE_ENTRIES[-1]
