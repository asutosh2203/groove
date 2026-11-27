import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import unittest

import kove_statusline as S
from kove_logic import Hub

HERE = os.path.dirname(os.path.abspath(__file__))
FUTURE = 4102444800  # 2100


def payload(**kw):
    p = {"session_id": "s1", "transcript_path": "/home/u/SECRET.jsonl", "cwd": "/home/u/SECRETDIR",
         "model": {"display_name": "SECRETMODEL"}, "workspace": {"current_dir": "/x"},
         "rate_limits": {"five_hour": {"used_percentage": 34.2, "resets_at": FUTURE},
                         "seven_day": {"used_percentage": 12, "resets_at": FUTURE + 5}},
         "context_window": {"used_percentage": 41, "current_usage": {"input_tokens": 9}},
         "cost": {"total_cost_usd": 1.8449, "total_lines_added": 84, "total_lines_removed": 12, "total_duration_ms": 5}}
    p.update(kw)
    return p


class ExtractTest(unittest.TestCase):
    def test_fields(self):
        m = S.extract(payload())
        self.assertEqual(m, {"hook_event_name": "StatusLine", "session_id": "s1", "contextPct": 41, "costUsd": 1.84,
                             "linesAdded": 84, "linesRemoved": 12,
                             "usage": {"fiveHour": {"pct": 34, "resetsAt": FUTURE}, "sevenDay": {"pct": 12, "resetsAt": FUTURE + 5}}})

    def test_privacy_nothing_else_leaves(self):
        text = json.dumps(S.extract(payload()))
        for secret in ("SECRET", "transcript", "cwd", "model", "workspace", "input_tokens"):
            self.assertNotIn(secret, text)

    def test_absent_windows_and_null_context(self):
        m = S.extract(payload(rate_limits={"five_hour": {"used_percentage": 5, "resets_at": FUTURE}}, context_window={"used_percentage": None}))
        self.assertEqual(list(m["usage"]), ["fiveHour"])
        self.assertIsNone(m["contextPct"])
        m = S.extract(payload(rate_limits=None))
        self.assertNotIn("usage", m)
        m = S.extract(payload(rate_limits={"spend_limit": {"used_percentage": 3, "resets_at": FUTURE}}))
        self.assertNotIn("usage", m)  # gateway spend is not a plan window (L1)

    def test_garbage_is_dropped_not_raised(self):
        self.assertIsNone(S.extract([]))
        self.assertIsNone(S.extract({"session_id": ""}))
        m = S.extract(payload(rate_limits={"five_hour": {"used_percentage": "x", "resets_at": True}}, cost={"total_cost_usd": float("nan")}))
        self.assertNotIn("usage", m)
        self.assertEqual(m["costUsd"], 0)


class ThrottleTest(unittest.TestCase):
    def test_changed_values_at_most_every_two_seconds(self):
        path = os.path.join(tempfile.mkdtemp(), "kove", "sl-x")
        a, b = S.extract(payload()), S.extract(payload(cost={"total_cost_usd": 3}))
        self.assertTrue(S.should_send(a, 100, path))
        self.assertFalse(S.should_send(a, 110, path))  # unchanged
        self.assertFalse(S.should_send(b, 101, path))  # changed but too soon: not recorded either
        self.assertTrue(S.should_send(b, 102.5, path))
        self.assertEqual(os.listdir(os.path.dirname(path)), ["sl-x"])  # no temp file left behind

    def test_one_state_file_per_session(self):
        self.assertNotEqual(S.state_file("a"), S.state_file("b"))
        self.assertEqual(S.state_file("a"), S.state_file("a"))


class RuntimeDirTest(unittest.TestCase):
    """No shared /tmp fallback: another local user could own that folder (and plant symlinks in it)."""

    def test_paths_live_only_in_xdg_runtime_dir(self):
        old = os.environ.pop("XDG_RUNTIME_DIR", None)
        try:
            self.assertIsNone(S.state_file("a"))
            self.assertIsNone(S.sock_path())
            os.environ["XDG_RUNTIME_DIR"] = "/run/user/1000"
            self.assertEqual(S.sock_path(), "/run/user/1000/kove/agents.sock")
            self.assertTrue(S.state_file("a").startswith("/run/user/1000/kove/sl-"))
        finally:
            os.environ.pop("XDG_RUNTIME_DIR", None)
            if old is not None:
                os.environ["XDG_RUNTIME_DIR"] = old

    def test_the_temp_write_never_follows_a_planted_symlink(self):
        d = tempfile.mkdtemp()
        victim = os.path.join(d, "victim")
        with open(victim, "w") as f:
            f.write("precious")
        path = os.path.join(d, "kove", "sl-x")
        os.makedirs(os.path.dirname(path))
        os.symlink(victim, "%s.%d.tmp" % (path, os.getpid()))  # the old predictable temp name
        self.assertTrue(S.should_send(S.extract(payload()), 100, path))
        with open(victim) as f:
            self.assertEqual(f.read(), "precious")
        with open(path) as f:
            self.assertIn("key", json.load(f))


class RunTest(unittest.TestCase):
    def run_helper(self, d, original=None, raw=None, listen=False, runtime=True):
        dest = os.path.join(d, "dest")
        os.makedirs(dest, exist_ok=True)
        for f in ("kove_statusline.py", "kove_hook.py"):
            with open(os.path.join(HERE, f)) as src, open(os.path.join(dest, f), "w") as out:
                out.write(src.read())
        if original is not None:
            with open(os.path.join(dest, "statusline-original.json"), "w") as f:
                json.dump(original, f)
        env = dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d, MARK="kept")
        if not runtime:
            del env["XDG_RUNTIME_DIR"]
        return subprocess.run([sys.executable, "-S", os.path.join(dest, "kove_statusline.py")],
                              input=raw if raw is not None else json.dumps(payload()).encode(), env=env, capture_output=True, timeout=10, cwd=d)

    def test_no_original_prints_nothing_and_exits_zero(self):
        r = self.run_helper(tempfile.mkdtemp())
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))

    def test_chains_original_with_raw_stdin_env_cwd_and_exit_status(self):
        d = tempfile.mkdtemp()
        cmd = 'cat >/dev/null; printf "%s|%s" "$MARK" "$(pwd)"; exit 3'
        r = self.run_helper(d, {"type": "command", "command": cmd})
        self.assertEqual(r.stdout.decode(), "kept|" + os.path.realpath(d))
        self.assertEqual(r.returncode, 3)

    def test_original_gets_the_unmodified_payload_even_if_unparsable(self):
        d = tempfile.mkdtemp()
        r = self.run_helper(d, {"type": "command", "command": "cat"}, raw=b"not json \xff")
        self.assertEqual(r.stdout, b"not json \xff")
        self.assertEqual(r.returncode, 0)

    def test_reports_to_the_socket_once_then_dedupes(self):
        d = tempfile.mkdtemp()
        os.makedirs(os.path.join(d, "kove"))
        srv = socket.socket(socket.AF_UNIX)
        srv.bind(os.path.join(d, "kove", "agents.sock"))
        srv.listen(4)
        got = []

        def serve():
            while True:
                c, _ = srv.accept()
                got.append(c.makefile().read())
                c.close()

        threading.Thread(target=serve, daemon=True).start()
        for _ in range(2):
            self.assertEqual(self.run_helper(d).returncode, 0)
        self.assertEqual(len(got), 1)
        self.assertEqual(json.loads(got[0])["usage"]["fiveHour"]["pct"], 34)

    def test_without_runtime_dir_it_still_chains_sends_nothing_and_hints_once(self):
        d = tempfile.mkdtemp()
        for _ in range(2):
            r = self.run_helper(d, {"type": "command", "command": "cat >/dev/null; printf ok"}, runtime=False)
            self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"ok", b""))
        self.assertFalse(os.path.exists(os.path.join(d, "kove", "agents.sock")))
        self.assertEqual([n for n in os.listdir(os.path.join(d, "kove")) if n.startswith("sl-")], [])
        with open(os.path.join(d, "kove", "claude-code.log")) as f:
            self.assertEqual(f.read().count("XDG_RUNTIME_DIR is unset"), 1)

    def test_garbage_logs_type_only(self):
        d = tempfile.mkdtemp()
        r = self.run_helper(d, raw=b"SECRET{")
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))
        with open(os.path.join(d, "kove", "claude-code.log")) as f:
            self.assertNotIn("SECRET", f.read())


def _have_bindings():
    return subprocess.run([sys.executable, "-c", "import dbus, gi"], capture_output=True).returncode == 0


@unittest.skipUnless(_have_bindings(), "install.sh needs python-dbus and PyGObject")
class InstallTest(unittest.TestCase):
    def install(self, home, flag):
        env = dict(os.environ, HOME=home, XDG_DATA_HOME=os.path.join(home, "data"))
        r = subprocess.run(["sh", os.path.join(HERE, "install.sh"), flag], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def settings(self, home, value=None):
        p = os.path.join(home, ".claude", "settings.json")
        if value is not None:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            json.dump(value, open(p, "w"))
        return json.load(open(p)) if os.path.exists(p) else None

    def roundtrip(self, original):
        home = tempfile.mkdtemp()
        start = {"theme": "dark", "hooks": {"Stop": []}}
        if original is not None:
            start["statusLine"] = original
        self.settings(home, start)
        out = self.install(home, "--statusline")
        self.assertIn("before:", out)
        now = self.settings(home)["statusLine"]
        self.assertIn("kove_statusline.py", now["command"])
        for k, v in (original or {}).items():
            if k != "command":
                self.assertEqual(now[k], v)  # padding and friends survive
        self.assertEqual(len([f for f in os.listdir(os.path.join(home, ".claude")) if ".bak-" in f]), 1)
        self.assertIn("nothing changed", self.install(home, "--statusline"))  # idempotent: the original is not overwritten
        self.install(home, "--statusline-remove")
        self.assertEqual(self.settings(home), start)  # exactly the settings we began with
        self.assertFalse(os.path.exists(os.path.join(home, "data", "kove", "claude-code", "statusline-original.json")))

    def test_restores_an_original_status_line(self):
        self.roundtrip({"type": "command", "command": "echo hi", "padding": 2})

    def test_removes_the_key_when_there_was_none(self):
        self.roundtrip(None)


class HubUsageTest(unittest.TestCase):
    def report(self, h, now, sid="s1", **kw):
        return h.handle(S.extract(payload(session_id=sid, **kw)), now)

    def test_never_creates_a_session_but_is_applied_when_one_starts(self):
        h = Hub()
        self.report(h, 10)
        self.assertEqual(h.snapshot()["sessions"], [])
        h.handle({"session_id": "s1", "hook_event_name": "UserPromptSubmit", "cwd": "/x/p"}, 11)
        s = h.snapshot()["sessions"][0]
        self.assertEqual((s["contextPct"], s["costUsd"], s["linesAdded"], s["linesRemoved"]), (41, 1.84, 84, 12))

    def test_a_report_without_a_window_does_not_clear_it(self):
        h = Hub()
        self.report(h, 10)
        self.report(h, 11, sid="new", rate_limits=None)  # a new session has no limits until its first response
        self.report(h, 12, rate_limits={"five_hour": {"used_percentage": 50, "resets_at": FUTURE}})
        u = h.snapshot()["usage"]
        self.assertEqual((u["fiveHour"]["pct"], u["sevenDay"]["pct"]), (50, 12))  # replaced by a newer report; the other kept

    def test_window_expires_only_at_its_reset(self):
        h = Hub()
        self.report(h, 10, rate_limits={"five_hour": {"used_percentage": 9, "resets_at": 100}, "seven_day": {"used_percentage": 1, "resets_at": 500}})
        self.assertFalse(h.tick(99))
        self.assertEqual(sorted(h.snapshot()["usage"]), ["fiveHour", "sevenDay"])
        self.assertTrue(h.tick(100))
        self.assertEqual(list(h.snapshot()["usage"]), ["sevenDay"])
        self.assertTrue(h.tick(500))
        self.assertNotIn("usage", h.snapshot())

    def test_expired_window_in_a_report_is_ignored(self):
        h = Hub()
        self.report(h, 200, rate_limits={"five_hour": {"used_percentage": 9, "resets_at": 100}})
        self.assertNotIn("usage", h.snapshot())

    def test_deadline_wakes_for_a_reset_while_sessions_exist(self):
        h = Hub()
        h.handle({"session_id": "s1", "hook_event_name": "UserPromptSubmit", "cwd": "/x"}, 10)
        self.report(h, 11, rate_limits={"five_hour": {"used_percentage": 9, "resets_at": 100}})
        self.assertEqual(h.deadline(12, 60), 100)

    def test_metrics_are_bounded_and_dropped_at_session_end(self):
        h = Hub()
        for i in range(100):
            self.report(h, 10, sid="x%d" % i)
        self.assertLessEqual(len(h.metrics), 64)
        h.handle({"session_id": "x99", "hook_event_name": "SessionEnd"}, 11)
        self.assertNotIn("x99", h.metrics)

    def test_hostile_values_are_clamped(self):
        h = Hub()
        h.handle({"session_id": "s", "hook_event_name": "StatusLine", "usage": {"fiveHour": {"pct": 900, "resetsAt": FUTURE}, "bogus": {"pct": 1, "resetsAt": FUTURE}},
                  "contextPct": -5, "costUsd": "x", "linesAdded": 1e30, "linesRemoved": None}, 1)
        self.assertEqual(h.usage, {"fiveHour": {"pct": 100, "resetsAt": FUTURE, "at": 1}})
        self.assertEqual(h.metrics["s"]["contextPct"], 0)
        self.assertEqual(h.metrics["s"]["costUsd"], 0)


if __name__ == "__main__":
    unittest.main()


class HookUsageTest(unittest.TestCase):
    """Any hook payload that carries rate_limits reports usage (a VS Code session would, if Claude Code ever adds it)."""

    def payload(self, **kw):
        return dict({"session_id": "vs1", "cwd": "/x/p", "hook_event_name": "PreToolUse", "tool_name": "Read",
                     "tool_input": {"file_path": "/x"}, "transcript_path": "/secret/t.jsonl",
                     "rate_limits": {"five_hour": {"used_percentage": 41.6, "resets_at": 4102444800},
                                     "seven_day": {"used_percentage": "x", "resets_at": 4102444800}}}, **kw)

    def run_hook(self, payload):
        d = tempfile.mkdtemp()
        os.makedirs(os.path.join(d, "kove"))
        srv = socket.socket(socket.AF_UNIX)
        srv.bind(os.path.join(d, "kove", "agents.sock"))
        srv.listen(2)
        srv.settimeout(5)
        env = dict(os.environ, XDG_RUNTIME_DIR=d, XDG_STATE_HOME=d)
        subprocess.run([sys.executable, "-S", os.path.join(HERE, "kove_hook.py")], input=json.dumps(payload).encode(), env=env, timeout=10)
        c, _ = srv.accept()
        return json.loads(c.makefile().read())

    def test_the_hook_forwards_the_windows_and_nothing_else_new(self):
        msg = self.run_hook(self.payload())
        self.assertEqual(msg["usage"], {"fiveHour": {"pct": 42, "resetsAt": 4102444800}})  # the malformed window is absent
        self.assertNotIn("transcript_path", msg)
        self.assertNotIn("rate_limits", msg)

    def test_a_payload_without_rate_limits_adds_nothing(self):
        p = self.payload()
        del p["rate_limits"]
        self.assertNotIn("usage", self.run_hook(p))

    def test_the_hub_takes_usage_from_any_event_with_the_same_absence_rules(self):
        h = Hub()
        h.handle({"session_id": "vs1", "hook_event_name": "PreToolUse", "tool_name": "Read", "cwd": "/x/p",
                  "usage": {"fiveHour": {"pct": 42, "resetsAt": 4102444800}, "sevenDay": {"pct": 10, "resetsAt": 4102444800}}}, 100)
        self.assertEqual(h.snapshot()["usage"]["fiveHour"], {"pct": 42, "resetsAt": 4102444800, "at": 100})
        # a later event carrying only one window replaces that one and never clears the other
        h.handle({"session_id": "vs1", "hook_event_name": "PreToolUse", "tool_name": "Read", "cwd": "/x/p",
                  "usage": {"fiveHour": {"pct": 50, "resetsAt": 4102444800}}}, 200)
        u = h.snapshot()["usage"]
        self.assertEqual((u["fiveHour"]["pct"], u["fiveHour"]["at"], u["sevenDay"]["at"]), (50, 200, 100))
        # an event without usage, or with an expired window, changes nothing
        h.handle({"session_id": "vs1", "hook_event_name": "PreToolUse", "tool_name": "Read", "cwd": "/x/p"}, 300)
        h.handle({"session_id": "vs1", "hook_event_name": "PreToolUse", "tool_name": "Read", "cwd": "/x/p",
                  "usage": {"fiveHour": {"pct": 99, "resetsAt": 5}}}, 400)
        self.assertEqual(h.snapshot()["usage"]["fiveHour"]["pct"], 50)
        # usage arrives even from an event with no session id
        h2 = Hub()
        h2.handle({"hook_event_name": "Notification", "usage": {"sevenDay": {"pct": 7, "resetsAt": 4102444800}}}, 10)
        self.assertEqual(h2.snapshot()["usage"]["sevenDay"]["pct"], 7)
        self.assertEqual(h2.snapshot()["sessions"], [])
