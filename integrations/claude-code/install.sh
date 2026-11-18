#!/bin/sh
# Copies the bridge to ~/.local/share/kove/claude-code/ and prints the hooks snippet. With --merge it also adds the
# hooks to ~/.claude/settings.json (backup first); without it your settings are never touched.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dest="${XDG_DATA_HOME:-$HOME/.local/share}/kove/claude-code"

python3 -c "import dbus, gi" 2>/dev/null || {
  echo "python-dbus or PyGObject is missing. Install: Arch: python-dbus python-gobject | Debian/Ubuntu: python3-dbus python3-gi | Fedora: python3-dbus python3-gobject | openSUSE: python3-dbus-python python3-gobject" >&2
  exit 1
}
mkdir -p "$dest"
cp "$here/kove_hook.py" "$here/kove_daemon.py" "$here/kove_logic.py" "$dest/"

python3 - "$dest" "${1:-}" <<'PY'
import json, os, shutil, sys, time
dest, merge = sys.argv[1], sys.argv[2] == "--merge"
cmd = "python3 -S %s/kove_hook.py" % dest
events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest", "PermissionDenied", "SubagentStart", "SubagentStop", "Notification", "TaskCreated", "TaskCompleted", "Stop", "SessionEnd"]
snippet = {"hooks": {e: [{"hooks": [{"type": "command", "command": cmd}]}] for e in events}}
if not merge:
    print(json.dumps(snippet, indent=2))
    print("\nAdd the above to ~/.claude/settings.json (merge the \"hooks\" keys), or re-run with --merge.", file=sys.stderr)
    sys.exit()
path = os.path.expanduser("~/.claude/settings.json")
cfg = json.load(open(path)) if os.path.exists(path) else {}
if os.path.exists(path):
    shutil.copy2(path, "%s.bak-kove-%d" % (path, time.time()))
for e, entry in snippet["hooks"].items():
    lst = cfg.setdefault("hooks", {}).setdefault(e, [])
    if not any(cmd in h.get("command", "") for g in lst for h in g.get("hooks", [])):
        lst.extend(entry)
json.dump(cfg, open(path, "w"), indent=2)
print("merged into", path)
PY
