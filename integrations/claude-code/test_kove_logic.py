import unittest
import json
import os
import subprocess
import sys
import tempfile
from kove_logic import *


class T(unittest.TestCase):
    def test_project(self):
        self.assertEqual(project_name("/a/b/groove/", lambda p: False), "groove")
        self.assertEqual(project_name("", lambda p: False), "project")

    def test_project_is_the_git_root(self):
        d = tempfile.mkdtemp()
        repo, sub, wt, plain = (os.path.join(d, x) for x in ("groove", "groove/contents/ui", "tree", "notes/today"))
        for p in (sub, wt, plain):
            os.makedirs(p)
        os.mkdir(os.path.join(repo, ".git"))
        with open(os.path.join(wt, ".git"), "w") as f:
            f.write("gitdir: /elsewhere")  # a worktree's .git is a file
        self.assertEqual(project_name(sub), "groove")
        self.assertEqual(project_name(repo), "groove")
        self.assertEqual(project_name(wt), "tree")
        self.assertEqual(project_name(plain), "today")

    def test_routes(self):
        r = Routes(cap=2)
        r.remember(1, "a")
        r.remember(2, "b")
        r.remember(3, "c")
        self.assertIsNone(r.session_for(1, "default"))  # evicted
        self.assertEqual(r.session_for(3, "default"), "c")
        self.assertIsNone(r.session_for(3, "other"))
        self.assertIsNone(r.session_for(99, "default"))

    def test_notifications_carry_their_session(self):
        out = Hub().handle(self.ev("PermissionRequest", tool_name="Bash", tool_input={}), 1)
        self.assertEqual(out[0]["sid"], "s1")

    def test_action(self):
        self.assertEqual(action_for_tool("Edit", {"file_path": "/x/main.qml"}), ("edit", "main.qml"))
        self.assertEqual(action_for_tool("Bash", {"command": "npm  test --  --watch all now"}), ("run", "npm test -- --watch"))
        self.assertEqual(action_for_tool("Grep", {}), ("search", ""))
        self.assertEqual(action_for_tool("Weird", None), ("other", ""))
        self.assertEqual(waiting_command("Bash", {"command": "rm -rf  build"}), "rm -rf build")
        self.assertEqual(waiting_command("Edit", {"file_path": "a/m.qml"}), "Editing m.qml")

    def test_scope(self):
        self.assertEqual(scope_app_id("app-com.microsoft.VSCode-3386.scope"), "com.microsoft.VSCode")
        self.assertEqual(scope_app_id("app-flatpak-org.mozilla.firefox-99.scope"), "org.mozilla.firefox")
        self.assertEqual(scope_app_id("app-gnome-code-12.scope"), "code")
        self.assertEqual(scope_app_id("app-org.x.my-app-3.scope"), "org.x.my-app")
        self.assertEqual(scope_app_id("tab(1547).scope"), "")
        self.assertEqual(scope_app_id(""), "")

    def test_status(self):
        self.assertEqual(status_for_tool("Edit", {"file_path": "/x/main.qml"}), "Editing main.qml")
        self.assertEqual(status_for_tool("Bash", {"command": "node --test tests/*.cjs"}), "Running tests")
        self.assertEqual(status_for_tool("Bash", {"command": "ls"}), "Running a command")
        self.assertEqual(status_for_tool("WebSearch", {}), "Searching the web")
        self.assertEqual(status_for_tool("Weird", None), "Working")

    def test_sentence(self):
        self.assertEqual(first_sentence("**Done.** Fixed `foo`.\n\n```py\nx=1\n```"), "Done.")
        self.assertEqual(first_sentence("I fixed `foo` in [bar](http://x). More."), "I fixed foo in bar.")
        self.assertEqual(first_sentence("# Title\nSomething v1.2 works"), "Title Something v1.2 works")
        self.assertEqual(len(first_sentence("a" * 200)), 80)
        self.assertEqual(first_sentence(None), "")

    def test_counts(self):
        self.assertEqual(task_counts({}), (0, 0, ""))
        t = {"1": {"subject": "A", "status": "completed"}, "2": {"subject": "B", "status": "in_progress"},
             "3": {"subject": "C", "status": "pending"}}
        self.assertEqual(task_counts(t), (1, 3, "B"))

    def test_threshold(self):
        self.assertTrue(done_ping(30, 30))
        self.assertFalse(done_ping(29.9, 30))

    def ev(self, kind, **kw):
        return dict(hook_event_name=kind, session_id="s1", cwd="/p/groove", **kw)

    def snap(self, hub, i=0):
        return hub.snapshot()["sessions"][i]

    def test_sleep_grammar(self):
        ok = {"sleep 5": 5, "sleep 5s": 5, "sleep 5m": 300, "sleep 2h": 7200, "sleep 0.5": 0.5, "  sleep   90 \n": 90, "sleep 1.5m": 90}
        for cmd, total in ok.items():
            self.assertEqual(parse_sleep(cmd), total, cmd)
        for cmd in ("sleep 5 && x", "sleep 5; x", "sleep $N", "sleep 1 2", "sleep 5 &", "sleep", "sleep 0", "sleep -1", "sleep 5d",
                    "sleep 5 | cat", "x && sleep 5", "sleep 5\nls", "sleep 1e3", "sleep inf", "while true; do sleep 1; done",
                    "./sleep 5", "sleep 5m # wait", "sleep $(echo 5)", "", None):
            self.assertIsNone(parse_sleep(cmd), cmd)

    def bash(self, h, tid, cmd, now, **kw):
        return h.handle(self.ev("PreToolUse", tool_name="Bash", tool_use_id=tid, tool_input={"command": cmd}, **kw), now)

    def test_command_timer_and_countdown(self):
        h = Hub()
        self.bash(h, "t1", "npm test", 100)
        s = self.snap(h)
        self.assertEqual((s["toolStartedAt"], s["countdown"]), (100, None))
        h.handle(self.ev("PostToolUse", tool_use_id="t1"), 130)
        self.assertEqual(self.snap(h)["toolStartedAt"], 0)
        self.bash(h, "t2", "sleep 5m", 200)
        self.assertEqual(self.snap(h)["countdown"], {"total": 300, "startedAt": 200})
        h.handle(self.ev("PostToolUseFailure", tool_use_id="t2"), 210)  # a failed or interrupted tool ends too
        self.assertIsNone(self.snap(h)["countdown"])
        self.bash(h, "t3", "sleep 5 && echo hi", 300)
        self.assertIsNone(self.snap(h)["countdown"])
        self.assertEqual(self.snap(h)["toolStartedAt"], 300)

    def test_subagent_tools_do_not_drive_the_timer_and_stop_clears(self):
        h = Hub()
        self.bash(h, "t1", "sleep 60", 10, agent_id="a1")
        self.assertEqual(self.snap(h)["toolStartedAt"], 0)
        self.bash(h, "t2", "make", 20)
        self.bash(h, "t3", "sleep 30", 25)
        self.assertEqual(self.snap(h)["countdown"]["startedAt"], 25)  # the latest running tool leads
        h.handle(self.ev("PostToolUse", tool_use_id="t3"), 30)
        self.assertEqual(self.snap(h)["toolStartedAt"], 20)
        h.handle(self.ev("PermissionDenied", tool_use_id="t2"), 31)
        self.assertEqual(self.snap(h)["toolStartedAt"], 0)
        self.bash(h, "t4", "make", 40)
        h.handle(self.ev("Stop"), 50)
        self.assertEqual(self.snap(h)["toolStartedAt"], 0)

    def test_permission_prompt_drops_the_unknown_start(self):
        h = Hub()
        self.bash(h, "t1", "sleep 30", 10)
        h.handle(self.ev("PermissionRequest", tool_name="Bash", tool_input={"command": "sleep 30"}), 11)
        self.assertEqual((self.snap(h)["toolStartedAt"], self.snap(h)["countdown"]), (0, None))

    def test_subagents_tracked_and_bounded(self):
        h = Hub()
        h.handle(self.ev("SubagentStart", agent_id="a1", agent_type="Explore"), 1)
        h.handle(self.ev("SubagentStart", agent_id="a2", agent_type="Plan"), 2)
        self.assertEqual(self.snap(h)["subagents"], [{"id": "a1", "type": "Explore"}, {"id": "a2", "type": "Plan"}])
        h.handle(self.ev("SubagentStop", agent_id="a1", agent_type="Explore"), 3)
        self.assertEqual(self.snap(h)["subagents"], [{"id": "a2", "type": "Plan"}])
        h.handle(self.ev("SubagentStop", agent_id="nope"), 4)
        for i in range(40):
            h.handle(self.ev("SubagentStart", agent_id="x%d" % i), 5)
        self.assertEqual(len(self.snap(h)["subagents"]), MAX_TRACKED)
        h.handle(self.ev("UserPromptSubmit"), 6)
        self.assertEqual(self.snap(h)["subagents"], [])

    def test_running_tools_bounded(self):
        h = Hub()
        for i in range(50):
            self.bash(h, "t%d" % i, "make", i)
        self.assertEqual(len(h.sessions["s1"].running), MAX_TRACKED)

    def test_snapshot_never_carries_the_command(self):
        h = Hub()
        self.bash(h, "t1", "sleep 5m", 1)  # only the existing short target (D-57) shows it; the new fields are numbers
        s = self.snap(h)
        self.assertEqual(set(s["countdown"]), {"total", "startedAt"})
        self.assertNotIn("command", json.dumps(s).replace("waitingCommand", ""))

    def test_deadline(self):
        h = Hub()
        self.assertEqual(h.deadline(5, 60), 65)  # empty: the idle exit
        self.assertEqual(h.deadline(30, 60), 65)
        self.bash(h, "t1", "make", 100)
        self.assertEqual(h.deadline(101, 60), 100 + IDLE_TIMEOUT)
        h.handle(self.ev("PermissionRequest", tool_name="Bash", tool_input={}), 110)
        self.assertIsNone(h.deadline(111, 60))  # waiting never expires: no wakeup at all
        h.handle(self.ev("Stop"), 120)
        self.assertEqual(h.deadline(121, 60), 120 + DONE_LINGER)

    def test_working_and_done(self):
        h = Hub()
        h.handle(self.ev("PreToolUse", tool_name="Edit", tool_input={"file_path": "a/m.qml"}), 1)
        s = self.snap(h)
        self.assertEqual((s["state"], s["action"], s["target"], s["project"], s["agent"]), ("working", "edit", "m.qml", "groove", "claude-code"))
        self.assertNotIn("lastMessage", s)
        out = h.handle(self.ev("Stop", last_assistant_message="All set. Bye"), 40)
        s = self.snap(h)
        self.assertEqual((s["state"], s["lastMessage"]), ("done", "All set."))
        self.assertEqual(out[0]["summary"], "groove · All set.")
        self.assertEqual(json.loads(json.dumps(h.snapshot()))["v"], 1)

    def test_short_run_no_ping(self):
        h = Hub()
        h.handle(self.ev("PreToolUse", tool_name="Read", tool_input={}), 0)
        self.assertEqual(h.handle(self.ev("Stop", last_assistant_message="ok."), 5), [])

    def test_waiting_notifies_and_clears(self):
        h = Hub()
        out = h.handle(self.ev("PermissionRequest", tool_name="Bash", tool_input={"command": "rm -rf build"}), 1)
        self.assertTrue(out[0]["urgent"])
        self.assertEqual(out[0]["summary"], "groove · Needs your OK")
        s = self.snap(h)
        self.assertEqual((s["state"], s["waitingCommand"], s["waitingAction"]), ("waiting", "rm -rf build", "run"))
        h.handle(self.ev("PostToolUse", tool_name="Bash", tool_input={}), 2)
        self.assertEqual(self.snap(h)["state"], "working")
        self.assertEqual((self.snap(h)["waitingCommand"], self.snap(h)["waitingAction"]), ("", ""))
        h.handle(self.ev("PermissionRequest", tool_name="Edit", tool_input={"file_path": "a/m.qml"}), 3)
        self.assertEqual((self.snap(h)["waitingCommand"], self.snap(h)["waitingAction"]), ("Editing m.qml", "edit"))

    def test_todos_and_task_events(self):
        h = Hub()
        todos = [{"content": "A", "status": "completed"}, {"content": "B", "status": "in_progress"}]
        h.handle(self.ev("PreToolUse", tool_name="TodoWrite", tool_input={"todos": todos}), 1)
        s = self.snap(h)
        self.assertEqual((s["done"], s["total"], s["task"]), (1, 2, "B"))
        g = Hub()
        g.handle(self.ev("TaskCreated", task_id="1", task_subject="A"), 1)
        g.handle(self.ev("TaskCreated", task_id="2", task_subject="B"), 1)
        g.handle(self.ev("TaskCompleted", task_id="1"), 2)
        self.assertEqual((self.snap(g)["done"], self.snap(g)["total"]), (1, 2))

    def test_linger_then_gone_and_new_prompt_restarts(self):
        h = Hub()
        h.handle(self.ev("PreToolUse", tool_name="Read", tool_input={}), 0)
        h.handle(self.ev("Stop", last_assistant_message="x."), 1)
        self.assertFalse(h.tick(10.9))
        self.assertTrue(h.tick(11))
        self.assertEqual(h.snapshot()["sessions"], [])
        h.handle(self.ev("Stop", last_assistant_message="x."), 20)
        h.handle(self.ev("PreToolUse", tool_name="Read", tool_input={}), 21)  # straggler
        self.assertEqual(self.snap(h)["state"], "done")
        h.handle(self.ev("UserPromptSubmit"), 22)
        self.assertEqual((self.snap(h)["state"], self.snap(h)["startedAt"]), ("working", 22))

    def test_expiry_spares_waiting(self):
        h = Hub()
        h.handle(self.ev("PermissionRequest", tool_name="Bash", tool_input={}), 0)
        h.handle(dict(self.ev("PreToolUse", tool_name="Read", tool_input={}), session_id="s2"), 0)
        self.assertTrue(h.tick(IDLE_TIMEOUT + 1))
        self.assertEqual([s["id"] for s in h.snapshot()["sessions"]], ["s1"])

    def test_session_start_end_and_idle(self):
        h = Hub()
        h.handle(self.ev("SessionStart"), 0)
        self.assertEqual(h.snapshot()["sessions"], [])
        self.assertEqual(h.idle_for(0), 0)
        self.assertEqual(h.idle_for(61), 61)
        h.handle(self.ev("UserPromptSubmit"), 62)
        self.assertEqual(h.idle_for(63), 0)
        h.handle(self.ev("SessionEnd"), 64)
        self.assertEqual(h.snapshot()["sessions"], [])

    def test_pids_and_scope(self):
        h = Hub()
        h.handle(self.ev("UserPromptSubmit", pids=[502116, 3646, 3386], scope="app-com.microsoft.VSCode-3386.scope"), 0)
        s = self.snap(h)
        self.assertEqual((s["pids"], s["scopeApp"]), ([502116, 3646, 3386], "com.microsoft.VSCode"))
        self.assertNotIn("scope", s)
        self.assertNotIn("cwd", s)

    def test_ordering_by_start(self):
        h = Hub()
        h.handle(dict(self.ev("UserPromptSubmit"), session_id="b"), 5)
        h.handle(dict(self.ev("UserPromptSubmit"), session_id="a"), 1)
        self.assertEqual([s["id"] for s in h.snapshot()["sessions"]], ["a", "b"])

    def test_log_never_has_content(self):
        logged = []
        secret = "SECRET-COMMAND-rm-rf"
        ingest(Hub(), ('{"session_id": "x", "tool_input": {"command": "%s"' % secret).encode(), 0, logged.append)
        ingest(Hub(), b"[1]", 0, logged.append)
        ingest(Hub(), json.dumps({"session_id": "x", "hook_event_name": "PreToolUse", "tool_name": secret,
                                  "tool_input": {"command": secret, "file_path": secret}}).encode(), 0, logged.append)
        self.assertEqual(len(logged), 1)
        self.assertNotIn(secret, " ".join(logged))


class HookTest(unittest.TestCase):
    def test_ancestors_stop_before_systemd(self):
        import kove_hook
        proc = tempfile.mkdtemp()
        for pid, comm, ppid in ((30, "claude", 20), (20, "code (x)", 10), (10, "systemd", 1)):
            os.mkdir(os.path.join(proc, str(pid)))
            with open(os.path.join(proc, str(pid), "stat"), "w") as f:
                f.write("%d (%s) S %d 0" % (pid, comm, ppid))
        self.assertEqual(kove_hook.ancestors(30, proc), [30, 20])

    def sandboxed(self, d_state, d_run):
        info = os.path.join(d_state, "flatpak-info")
        open(info, "w").close()
        ev = json.dumps({"session_id": "s", "hook_event_name": "UserPromptSubmit"}).encode()
        here = os.path.dirname(os.path.abspath(__file__))
        env = dict(os.environ, XDG_RUNTIME_DIR=d_run, XDG_STATE_HOME=d_state, KOVE_FLATPAK_INFO=info)
        return subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")], input=ev, env=env, capture_output=True, timeout=10)

    def test_sandbox_never_spawns_and_hints_once(self):
        import time
        st, run = tempfile.mkdtemp(), tempfile.mkdtemp()
        for _ in range(2):
            r = self.sandboxed(st, run)
            self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))
        time.sleep(1)
        self.assertFalse(os.path.exists(os.path.join(run, "kove")))  # a spawned aggregator would have made its socket dir
        with open(os.path.join(st, "kove", "claude-code.log")) as f:
            self.assertEqual(f.read().count("sandboxed"), 1)

    def run_hook(self, event, env_extra=None):
        d = tempfile.mkdtemp()
        env = dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d, **(env_extra or {}))
        here = os.path.dirname(os.path.abspath(__file__))
        r = subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")], input=json.dumps(event).encode(),
                           env=env, capture_output=True, timeout=10)
        return r, d

    def test_silent_exit_zero_without_aggregator_for_other_events(self):
        r, d = self.run_hook({"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
                              "tool_input": {"command": "SECRET"}})
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))
        self.assertFalse(os.path.exists(os.path.join(d, "kove")))

    def test_garbage_input_logs_type_only(self):
        d = tempfile.mkdtemp()
        here = os.path.dirname(os.path.abspath(__file__))
        r = subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")], input=b"SECRET{",
                           env=dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d), capture_output=True)
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))
        with open(os.path.join(d, "kove", "claude-code.log")) as f:
            self.assertNotIn("SECRET", f.read())


def _bus_has_aggregator():
    try:
        if subprocess.run(["busctl", "--user", "list"], capture_output=True, timeout=5).returncode != 0:
            return None  # no session bus (CI container)
        r = subprocess.run(["busctl", "--user", "status", "io.github.asutosh2203.Kove.Agents"], capture_output=True, timeout=5)
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return None  # no busctl or session bus: skip


@unittest.skipUnless(_bus_has_aggregator() is False, "needs a session bus with no Kove aggregator running")
class AggregatorTest(unittest.TestCase):
    def test_hook_spawns_serves_snapshot_and_exits_idle(self):
        import time
        d = tempfile.mkdtemp()
        env = dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d, KOVE_CLAUDE_IDLE_EXIT_SECONDS="3")
        here = os.path.dirname(os.path.abspath(__file__))
        ev = {"session_id": "t1", "cwd": "/p/groove", "hook_event_name": "UserPromptSubmit"}
        subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")], input=json.dumps(ev).encode(), env=env, timeout=10)
        out = ""
        for _ in range(30):
            time.sleep(0.2)
            r = subprocess.run(["busctl", "--user", "call", "io.github.asutosh2203.Kove.Agents", "/io/github/asutosh2203/Kove/Agents",
                                "io.github.asutosh2203.Kove.Agents1", "List"], capture_output=True, text=True)
            if r.returncode == 0:
                out = r.stdout
                break
        self.assertIn("groove", out)
        end = dict(ev, hook_event_name="SessionEnd")
        subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")], input=json.dumps(end).encode(), env=env, timeout=10)
        for _ in range(60):
            time.sleep(0.2)
            if _bus_has_aggregator() is False:
                return
        self.fail("aggregator did not exit")

    def test_notification_click_emits_raise_requested(self):
        import time
        d = tempfile.mkdtemp()
        env = dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d, KOVE_CLAUDE_IDLE_EXIT_SECONDS="3", KOVE_TEST_NO_NOTIFY="1")
        here = os.path.dirname(os.path.abspath(__file__))
        hook = lambda ev: subprocess.run([sys.executable, "-S", os.path.join(here, "kove_hook.py")],
                                         input=json.dumps(ev).encode(), env=env, timeout=10)
        mon = subprocess.Popen(["busctl", "--user", "monitor", "--json=short", "-N", "1",
                                "--match", "type='signal',interface='io.github.asutosh2203.Kove.Agents1',member='RaiseRequested'"],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        hook({"session_id": "t2", "cwd": "/p/x", "hook_event_name": "UserPromptSubmit"})  # only prompts spawn it
        for _ in range(30):
            time.sleep(0.2)
            if _bus_has_aggregator():
                break
        hook({"session_id": "t2", "cwd": "/p/x", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_input": {}})
        time.sleep(0.5)
        emit = ["busctl", "--user", "emit", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "ActionInvoked", "us"]
        subprocess.run(emit + ["999", "default"], timeout=5)  # unknown id: nothing
        subprocess.run(emit + ["1000", "default"], timeout=5)
        out, _ = mon.communicate(timeout=10)
        self.assertIn("t2", out)
        hook({"session_id": "t2", "cwd": "/p/x", "hook_event_name": "SessionEnd"})
        for _ in range(60):
            time.sleep(0.2)
            if _bus_has_aggregator() is False:
                return
        self.fail("aggregator did not exit")


if __name__ == "__main__":
    unittest.main()
