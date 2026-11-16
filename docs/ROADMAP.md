# Roadmap

Last updated: 16 November 2026. Decisions referenced as D-xx live in [DECISIONS.md](DECISIONS.md).

## Done
| Milestone | Scope | Commit |
|---|---|---|
| M1.1 | Fixed shell, Notch/Pill modes, 180×40 allocation | `ec4aae6` |
| M1.2 | Plasma panel integration, live floating/thickness switching | `e2e7243` |
| M1.2.1 | Notch-aware expanded geometry, rounded shoulders | `0741a75` |
| M1.2.2 | Expanded media polish, system-wide mute | `daed657` |
| M1.3 | Idle time and weather (Open-Meteo, manual location) | `ec378bd` |
| M1.3.1 | Meteocons assets, QML animation, idle polish | `0dcb095` |
| M1.4.1–M1.4.3 | Expanded notification rebuild, fixed geometry, adaptive density, urgency | `d7f8127`, `5f1e49b`, `fcc8007` |
| CC1–CC3 | Control Center media card, list clipping, relative timestamps | `a287728`, `17e6590` |
| CC4 | Control Center token consistency pass | `22d5d03` |
| — | Pill-mode Control Center side padding fix | `b1f6338` |
| CC5 | KDE Connect card: D-Bus state, empty/connected/not-nearby states, theme phone glyph, notification card action icons | `cac7071` |
| — | CI on Node 26, all Node tests auto-run | `2c58eb0`, `a9fc274` |
| Q3 | CI hardening: one job in a pinned Arch container (image tag + Archive snapshot), real qmllint over all QML and JS with a warning ratchet, Qt Quick tests in CI, Dependabot for actions (D-36, `docs/CI.md`) | `2157738`, `d9e206f`, `8dc04c6`, `d577e87` |
| Q1 | Performance: baseline script, finite unread pulse, gated position poll, one shared 8 fps clock, fullscreen pause, covered-pill fix (D-34); measurements in `docs/PERFORMANCE.md` | `f756d35`, `61f123a`, `e8dc61b`, `eecbf18`, `e4866a9`, `298c3a8`, `6fef95d`, `8802d5d` |
| — | Idle face after 30 s without playback (D-35) | `68605e5` |
| CC7 | Notification click-through: open the live action, URL or app (D-31), TasksModel window activation (D-32), whole-island hover target, single right-hand slot, popup timers hold on hover | `fd8d57b` |
| D-33 | Notification popup duration: app timeout shortens the setting (2 s floor), critical at least 6 s | `63eb31f` |
| Q2 | `main.qml` breakup (D-37): services, tested logic, `Strings.qml`, `shell/` components; per-file qmllint ratchet and probe | `17a85d1` ... `7571027` |
| G1 | Cursor glow on expanded surfaces and the Control Center (D-41, D-42): shader pipeline with a CI check, settings toggles, Control Center stays put on media changes; measured in `docs/PERFORMANCE.md` ("After G1") | `0184e1d`, `b59a6bd`, `cc482ff`, `4990889` |

CC6 (notification list density/scrolling) was dropped.

## Now
- Q2 final pass: the performance check is done (see `docs/PERFORMANCE.md`, "After Q2"); the final Q2 report is left.
- B1: still to look at live: the notice accent colours (Critical red, Normal orange, Low grey). The Theme settings tile and
  icon fix were checked on screen.

## B1: bug batch (done)
Found while moving code in Q2; behaviour was kept during the moves, then fixed one commit per item.
1. **Light/Dark tile applied stock Breeze and wiped custom setups.** *Done as D-40* (`b0ad920`): the tile is now "Theme
   settings" and only opens Global Theme settings; the widget never applies a theme, and a test scans for any code that could.
2. **Quote the KDE Connect device id** in "browse". *Done* (`f64e3aa`): both commands built by `KdeConnectState.deviceCommand`,
   tested through a real shell with 14 hostile ids.
3. **Mute with no default sink.** *Done* (`c6aa870`): calls `globalMuteSinks` (outputs only), tested with stubs.
4. **Volume display above 100 %.** *Done* (`54ac49f`): the reading runs to 150, checked on the real tile at 100-125-150.
5. **Notification priority (D-38).** *Done* (`34b653a`): explicit urgency mapping, new order, Low is not an activity.
6. **Media player selection (D-39).** *Done* (`55b6732`): explicit filter and sort keys, most recently started wins, all
   players seen. Follow-up (`3e178d4`): a ghost browser tab that claims to play no longer blocks the idle face (D-35).
7. **Notice accent colour.** *Done* (`04c9a78`): mapped from the urgency kind (Critical red, Normal orange, Low grey); the
   Control Center's critical marker no longer compares urgency numbers either, and a test guards against any such comparison.

## Next
1. **Frosted-glass spike** (D-23): time-boxed prototype of real KWin blur with a shape-matched region.
   - A small native C++ helper could provide both blur-behind (`KWindowEffects`) and input-region trimming (`QWindow::setMask`, which would remove the click-swallowing reply strip, D-43).
2. **Widget architecture**: Q2 produced the services and logic layers (D-37); formalise them, together with
   `ActivityProvider` / `ModuleRegistry`, into the widget contract (D-24, D-25).
3. **First new widget**: Mirror or AI Agent Status.
4. **What is left of the quality work:**
   - Lint warnings: 471 remain (the baseline is per file, `.github/qmllint-baseline.txt`), almost all in the Control Center
     tiles and a few views; move their translated text into `Strings.qml` the way `main.qml` did and give the views
     required properties, then lower the baselines.
   - Performance follow-ups (see `docs/PERFORMANCE.md`): the Control Center while open is measured (0.97%, see the Q2 section); the expanded media popup is re-measured (G1); still to re-measure: the notification popup, Pill mode; the "idle for 5 minutes"
     pause once an event-driven idle source exists for QML; `IslandButton` Canvas glyph repaints.
   - Not covered by tests yet: the click versus double-click discrimination (it lives in `IslandCompact` and `main.qml`'s
     click timer) and weather caching.

## Unscheduled
- **N1: inline notification reply: done on `feat/n1-inline-reply`, awaiting review** (D-43, D-44). Live-checked in Notch and
  Pill with a D-Bus test sender (`tests/tools/`); a real Telegram or KDE Connect check needs a test conversation.

## Widget library

### Design notes (draft, from planning chat)
- One expanded surface ("the deck"): [Live] -> [Presets 1-5] -> [Control Center, always last].
- Live page: ALL running long-running activities (media, jobs) stacked with their own controls; shown only when
  something is live. Notifications and keyboard layout stay as pop-ins over the deck, not pages.
- Presets: max 5; each is a user-picked set of widgets in a template (size classes S/M/L per widget, no freeform
  editor, D-24); the user picks which presets are in the cycle and their order. Preset sizes: small or large.
- Navigation: a single horizontal axis. Grouped indicator: pill = Live, dots = presets, gear = Control Center. Dots are
  clickable, plus horizontal touchpad swipe. No vertical page switching (it conflicts with scrolling content).
- Entry: click the capsule opens the deck (lands on Live if something is running, else the last-used page); idle hot
  zones keep calendar and forecast (D-12); double-click opens the Control Center page; Esc or an outside click closes.
- No presets configured: the deck is [Live] + [Control Center], about today's behaviour.
- The indicator hides when the deck has a single page (no live activity and no presets: the deck is just the Control
  Center, identical to the current behaviour).
- Transitions: silhouette morph plus content cross-fade; the window is pre-sized for the largest page in the cycle
  before the deck shows (the N1 resize lesson, D-43); only the visible page's widgets are loaded (principle 9).
- Open questions: the widget contract (sizes, settings, lifecycle, permissions), the preset editor UX, and
  context-aware presets (later).

### W1: Claude Code progress integration
An adapter script (`integrations/claude-code/`) that turns Claude Code hook events into KDE-standard signals; the island
needs no new code for v1 (it already renders jobs and notifications).
- Progress: TaskCreated/TaskCompleted become a KDE job ("3 of 7 steps"); PreToolUse becomes the job's status text
  ("Editing main.qml", "Running tests") plus elapsed time when there is no task list.
- Attention: Notification (permission_prompt / agent_needs_input) becomes a Critical-urgency notification (D-38) that
  opens the terminal or IDE on click (D-31); Stop becomes a "Done" notification.
- Hooks are synchronous: the script must return in milliseconds (fire the D-Bus calls in the background).
- State file per session_id; clean up on Stop/SessionEnd; stale-job timeout if Claude crashes.
- Multiple sessions are multiple jobs; the job is non-cancellable in v1.
- Ship a README and a hooks snippet to paste into Claude Code settings.
- Later: a dedicated AI Agent widget (multiple sessions, last message, subagents) once the widget contract exists.

## Backlog
- Glow 60 fps cap ready on `perf/glow-60fps`; needs a real-pointer before/after measurement.
- Reply shelf: multi-line input (v1 is a single line); host the notification's other actions (Mark as read, Mute) in the shelf.
- **Native popup coexistence:** detect whether Plasma's own notification popups are active; never change it automatically (D-05). Show a one-time dismissible hint and a permanent note in settings with an "Open notification settings" button; document in the README. Investigate the officially supported way to disable Plasma popups without stopping the notification server. Also verify the island respects Do Not Disturb (no popups while DND is on); if it does not, that is a bug.
- **Enhancement (low priority, revisit before a public release): icon fallback chains for the Control Center tiles (D-26).** Tiles tint glyphs as flat masks, so a theme that lacks a `-symbolic` name (or draws it in colour) shows a blob or nothing. Give each tile an ordered list of names (symbolic, then an alternative symbolic, then a plain icon drawn unmasked) and test with Breeze and Adwaita. Today only the Theme settings tile has a fallback, and `Tokens.js` `symbolic()` maps names to Breeze-style symbolics.
- The old "Theme" tile is retired from the editor palette (it opened the same page as "Theme settings"); the id stays known so saved layouts keep it.
- Known upstream issue, not fixed here: Firefox's MPRIS support is still maturing. After a seek on YouTube it drops `mpris:length` from its metadata update (we hold the last length for the same track and player, `MediaLength.js`) and then reports `Position` 0 until a pause or play, so the progress time sticks at 0:00. Related Firefox bugs: 1949425 (signals on position state changes), 1950461 (position advancing while paused), 1896774 (`mpris:length` only recently exposed). Seen on Firefox ESR, so the fixes may not have shipped there yet. A position workaround would guess wrong on a real restart from 0, so it is deliberately not done; revisit if Firefox keeps it
- Show a live notification's own actions (Reply, Mark as read, Mute) in the expanded popup; this is what will make mirrored KDE Connect notifications useful, since they have no default action
- Expired notifications can only open the app, not the exact chat: the chat target exists only as the live default action, which dies on expiry (Telegram, WhatsApp Web). Inherent to the notification protocol; revisit only if a sender exposes a URL
- Smart reply suggestions (parked: privacy and resource cost; candidate for a future opt-in AI widget)
- Notification queueing with "more waiting" indicator
- **Q4: native data sources.** Bluetooth: `bluetoothctl` -> BluezQt; Wi-Fi and network: `nmcli` -> the plasma-nm model;
  KDE Connect via its native QML module. The parsing and the "which line" decisions are already pure and tested
  (`Bluetooth.js`, `NetworkState.js`, `KdeConnectState.js`), so only the sources change.
- Found during Q2 (behaviour kept): `PlasmaNM.WirelessStatus` is instantiated in `ConnectivityService` but never read;
  the inline `StatusChip` component was dead code and was deleted; `kdeconnect-cli`/qdbus ids are only quoted in the
  "ring" command (B1 item 2).
- Project-wide icon migration to theme symbolic names (D-26), incl. `IslandButton` Canvas glyphs
- KDE Connect via its native QML module
- File shelf, system HUD, Bluetooth/USB events
- Release housekeeping: add maintainer to `metadata.json` authors (keep upstream credit), point
  Website/BugReportUrl at `groove`, README upstream/inspiration credits, own plugin ID/name
