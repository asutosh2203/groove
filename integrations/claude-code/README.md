# Claude Code → Kove

Shows a Claude Code run as a KDE job (progress in the island) and sends notifications. Kove already renders KDE jobs and
notifications, so there is no island code. Design: D-49 in `docs/DECISIONS.md`.

- **Job** (opt-in, `KOVE_CLAUDE_JOBS=1`): "Claude · <project> · <status>", one per session. Percent from the task list when
  there is one, otherwise no percent. Not cancellable. Shown as paused while Claude waits for you. Off by default: Plasma
  can crash on rapid job churn, see D-49 / D-50.
- **Needs your OK** (permission prompt, input request): immediate Critical notification.
- **Done**: only if the run took at least `KOVE_CLAUDE_DONE_MIN_SECONDS` (default 30); shows the first sentence of
  Claude's last message (markdown stripped, ~80 characters). Nothing else from the transcript is read or stored.
- Clicking a notification opens `KOVE_CLAUDE_DESKTOP_ENTRY` (default: the first installed of VS Code's common entries, else Konsole) through the island's click-through chain.

## Install
Needs `python-dbus` (Arch `python-dbus`, Debian/Ubuntu/Fedora `python3-dbus`, openSUSE `python3-dbus-python`).
`./install.sh` copies the scripts to `~/.local/share/kove/claude-code/` and prints the hooks snippet.
`./install.sh --merge` also adds it to `~/.claude/settings.json` after a timestamped backup.

## Uninstall
Remove the hook entries pointing at `kove_hook.py` from `~/.claude/settings.json` (or restore the `.bak-kove-*` file),
then `rm -r ~/.local/share/kove/claude-code`.

## Behaviour guarantees
The hook always exits 0, prints nothing and logs errors to `${XDG_STATE_HOME:-~/.local/state}/kove/claude-code.log`.
A helper daemon per session holds the job (a KDE job lives as long as its D-Bus connection) on
`$XDG_RUNTIME_DIR/kove-claude/<session>.sock`; after Stop the job stays for 10 s so a quick next prompt reuses it (terminating and creating jobs in quick succession
crashes plasmashell, see D-49); it is ended when that grace expires, on SessionEnd, or after 10 minutes without events
unless Claude is waiting for you.

## Jobs are opt-in
Without `KOVE_CLAUDE_JOBS=1` (set in the hook's environment) only notifications are sent. With it, no job is created
within 5 s of any job ending, in any session (shared stamp file in `$XDG_RUNTIME_DIR/kove-claude/`).

## Tests
`cd integrations/claude-code && python3 -m unittest -q`
