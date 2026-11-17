# Claude Code → Kove

Shows your Claude Code sessions in the island as a native Live activity, and sends notifications. Design: D-57 in
`docs/DECISIONS.md` (it replaces the KDE-job version of D-49).

## What shows where
- **Live page:** a tile per session. Working shows what Claude is doing ("Editing PresetEditor.qml", "Running: npm test…") and
  the elapsed minutes; with a task list it also shows the current task, "3 of 7" and a progress bar. Waiting shows
  "Needs your OK" in an accent colour with a dot on the glyph and "Wants to run: <command>". Done shows "Done · 18 min" and the
  first sentence of Claude's last message, and fades after 10 s. A busy page turns agents into compact rows above the transfers.
- **Closed island:** the agent glyph and "project · 3 of 7" with a task list, else "project · editing" (or running, reading, searching, working). While Claude waits for you it shows
  "Needs your OK" with the accent dot.
- **Click** a tile or an opened row to raise the window Claude runs in. Kove finds it from the process chain (and, for a
  Flatpak, the app id); it never guesses. If no window is found the tile is simply not clickable.
- **Notifications** (work without Kove): "Needs your OK" immediately at Critical urgency, and "Done" for runs of at least
  `KOVE_CLAUDE_DONE_MIN_SECONDS` (default 30) with Claude's first sentence. Clicking one raises the same window when Kove is running.
- There are **no approve/reject buttons** in v1; that is deliberately deferred.

## Install
Needs `python-dbus` and PyGObject (Arch `python-dbus python-gobject`, Debian/Ubuntu `python3-dbus python3-gi`, Fedora
`python3-dbus python3-gobject`, openSUSE `python3-dbus-python python3-gobject`). `./install.sh` copies the scripts to
`~/.local/share/kove/claude-code/` and prints the hooks snippet; `./install.sh --merge` also adds it to
`~/.claude/settings.json` after a timestamped backup. A session that was already running picked the hooks up on a later
tool call in testing; if yours does not, start a new session. Check that a prompt creates a tile.

## Privacy
Command text, file names, the task list and Claude's message are held in memory to be displayed and never stored or logged.
The logs (`${XDG_STATE_HOME:-~/.local/state}/kove/claude-code.log`) carry error types only. The aggregator also records each
session's process ids (no names or command lines) so Kove can find the right window.

## How it works
Hooks write one JSON event to `$XDG_RUNTIME_DIR/kove/agents.sock` (about 15 ms, always exit 0 and print nothing). The first
SessionStart or UserPromptSubmit starts one aggregator per user. It owns `io.github.asutosh2203.Kove.Agents` on the session
bus (`Agents1`: `List`, `Changed`, `RaiseRequested`, versioned JSON), and exits 60 s after its last session. Kove only
watches that name, so nothing runs while no session does. The protocol is agent-agnostic (kind "agent"): another agent can
use the same interface with no Kove change.

## Limits
- **tmux, screen, systemd services:** a session whose process chain has no window (and no app scope) is not clickable.
  It still shows, and notifications still work.
- **Flatpak terminals and editors** are sandboxed: their hooks never start the aggregator, and they can only reach it if you
  expose the socket directory, once per app:
  `flatpak override --user --filesystem=xdg-run/kove <app-id>`. Without it they log a one-time hint and do nothing.
- An event fired within milliseconds of the prompt that starts the aggregator can be dropped; real prompts and tool calls are
  seconds apart.

## Uninstall
Remove the hook entries pointing at `kove_hook.py` from `~/.claude/settings.json` (or restore the `.bak` file), then
`rm -r ~/.local/share/kove/claude-code`.

## Tests
`cd integrations/claude-code && python3 -m unittest -q` (the end-to-end tests need a session bus and no running aggregator and
skip otherwise).
