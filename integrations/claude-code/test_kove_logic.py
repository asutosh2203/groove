import unittest
from kove_logic import *


class T(unittest.TestCase):
    def test_project(self):
        self.assertEqual(project_name("/a/b/groove/"), "groove")
        self.assertEqual(project_name(""), "project")

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

    def test_progress(self):
        self.assertEqual(progress({}), (None, None))
        t = {"1": {"subject": "A", "status": "completed"}, "2": {"subject": "B", "status": "in_progress"},
             "3": {"subject": "C", "status": "pending"}}
        self.assertEqual(progress(t), (33, "1 of 3 · B"))

    def test_threshold(self):
        self.assertTrue(done_ping(30, 30))
        self.assertFalse(done_ping(29.9, 30))

    def run_events(self, *evs, start=0, done_min=30):
        r = Run("/p/groove", start, done_min)
        return r, [r.handle(e, t) for t, e in evs]

    def test_indeterminate_and_done(self):
        r, outs = self.run_events((1, {"hook_event_name": "PreToolUse", "tool_name": "Edit", "tool_input": {"file_path": "a/m.qml"}}),
                                  (40, {"hook_event_name": "Stop", "last_assistant_message": "All set. Bye"}))
        self.assertEqual(outs[0], [{"op": "job", "percent": None, "info": "Editing m.qml", "suspended": False}])
        self.assertEqual(outs[1][0]["summary"], "groove · All set.")
        self.assertEqual(outs[1][-1], {"op": "job", "percent": 100, "info": "Done", "suspended": False})

    def test_short_run_no_ping(self):
        _, outs = self.run_events((5, {"hook_event_name": "Stop", "last_assistant_message": "ok."}))
        self.assertEqual(outs[0], [{"op": "job", "percent": 100, "info": "Done", "suspended": False}])

    def test_todos_progress(self):
        todos = [{"content": "A", "status": "completed"}, {"content": "B", "status": "in_progress"}]
        _, outs = self.run_events((1, {"hook_event_name": "PreToolUse", "tool_name": "TodoWrite", "tool_input": {"todos": todos}}))
        self.assertEqual(outs[0][0]["percent"], 50)
        self.assertEqual(outs[0][0]["info"], "1 of 2 · B")

    def test_task_events(self):
        r, _ = self.run_events((1, {"hook_event_name": "TaskCreated", "task_id": "1", "task_subject": "A"}),
                               (2, {"hook_event_name": "TaskCreated", "task_id": "2", "task_subject": "B"}),
                               (3, {"hook_event_name": "TaskCompleted", "task_id": "1"}))
        self.assertEqual(progress(r.tasks), (50, "1 of 2"))

    def test_waiting_freezes_timeout(self):
        r, outs = self.run_events((1, {"hook_event_name": "PermissionRequest", "tool_name": "Write", "tool_input": {"file_path": "x/a.txt"}}))
        self.assertTrue(outs[0][0]["urgent"])
        self.assertTrue(outs[0][1]["suspended"])
        self.assertFalse(r.expired(1 + IDLE_TIMEOUT * 5))
        r.handle({"hook_event_name": "PostToolUse"}, 2)
        self.assertFalse(r.waiting)
        self.assertEqual(r.status, "Working")
        self.assertTrue(r.expired(2 + IDLE_TIMEOUT + 1))

    def test_input_notification(self):
        _, outs = self.run_events((1, {"hook_event_name": "Notification", "notification_type": "idle_prompt", "message": "hi"}))
        self.assertEqual(outs[0][0]["body"], "hi")
        _, outs = self.run_events((1, {"hook_event_name": "Notification", "notification_type": "auth_success"}))
        self.assertEqual(outs[0][0]["op"], "job")

    def test_pick_entry(self):
        have = {"code-oss", "org.kde.konsole"}.__contains__
        self.assertEqual(pick_entry("mine", {"mine", "code-oss"}.__contains__), "mine")
        self.assertEqual(pick_entry("code", have), "code-oss")
        self.assertEqual(pick_entry("", lambda e: False), "org.kde.konsole")

    def test_grace_reuses_job(self):
        r = Run("/p/groove", 0)
        r.handle({"hook_event_name": "UserPromptSubmit"}, 0)
        r.handle({"hook_event_name": "Stop"}, 5)
        self.assertFalse(r.expired(5 + GRACE - 1))
        self.assertTrue(r.expired(5 + GRACE))
        self.assertEqual(r.handle({"hook_event_name": "PreToolUse", "tool_name": "Edit"}, 6), [])  # stray event
        out = r.handle({"hook_event_name": "UserPromptSubmit"}, 8)
        self.assertEqual(out, [{"op": "job", "percent": 0, "info": "Working", "suspended": False}])
        self.assertFalse(r.expired(8 + GRACE + 1))  # grace cancelled: the idle rule applies again
        self.assertFalse(r.ended)

    def test_reuse_resets_run_state(self):
        r = Run("/p/groove", 0, done_min=30)
        r.handle({"hook_event_name": "PreToolUse", "tool_name": "TodoWrite", "tool_input": {"todos": [{"content": "A", "status": "completed"}]}}, 1)
        r.handle({"hook_event_name": "Stop"}, 40)
        r.handle({"hook_event_name": "UserPromptSubmit"}, 41)
        self.assertEqual(r.tasks, {})
        out = r.handle({"hook_event_name": "Stop", "last_assistant_message": "Quick."}, 45)  # 4 s run: no Done ping
        self.assertEqual([a["op"] for a in out], ["job"])

    def test_session_end_terminates_at_once(self):
        r = Run("/p/groove", 0)
        self.assertEqual(r.handle({"hook_event_name": "SessionEnd"}, 1), [{"op": "end"}])
        self.assertTrue(r.ended)

    def test_cooldown(self):
        self.assertEqual(cooldown_remaining(None, 100), 0)
        self.assertEqual(cooldown_remaining(100, 102), 3)
        self.assertEqual(cooldown_remaining(100, 105), 0)
        self.assertEqual(cooldown_remaining(100, 999), 0)
        self.assertEqual(cooldown_remaining(500, 100), JOB_COOLDOWN)  # timestamp from the future is capped


if __name__ == "__main__":
    unittest.main()
