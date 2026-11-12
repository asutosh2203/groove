# Roadmap

Last updated: 13 November 2026. Decisions referenced as D-xx live in [DECISIONS.md](DECISIONS.md).

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

CC6 (notification list density/scrolling) was dropped.

## Now
- **Q2: main.qml breakup** (services + tested logic, D-37). Done: foundation, AppLauncher, ControlLayout, MediaService,
  NotificationService, JobService, ConnectivityService, SystemControls. To do: step 8 ActivityResolver, step 9
  PanelController, then the final pass.
- **Queued before the Q2 final pass: thin NotificationService.** qmllint is partly blind to any file that instantiates
  `NotificationManager.Notifications` (an undefined call there is not flagged, see `docs/CI.md`), so move every pure
  decision it still holds (which rows count, sorting and latest-row choice, freshness, urgency, the open target, the
  presentation duration) into `logic/Notifications.js` with Node tests, leaving the service a thin model wrapper.

## Next
1. **Quality pass**
   - Performance follow-ups (the main work is done, see `docs/PERFORMANCE.md`): re-measure the Control Center
     while open now that its bars ride the shared clock; the "idle for 5 minutes" pause once an event-driven
     idle source exists for QML; `IslandButton` Canvas glyph repaints.
   - Test coverage: extract and test logic still inside `main.qml` (activity priority/pre-emption,
     media player scoring, urgency mapping, click/double-click, weather caching).
   - Launcher extraction: move the desktop-entry lookup, launch and TasksModel logic out of `main.qml`
     into a standalone launcher component.
   - Q2: reduce the qmllint "unqualified access" warnings (677 of the 687 baseline; `pragma ComponentBehavior: Bound`
     and required properties), then lower `.github/qmllint-baseline.txt`; it only ever goes down.
2. **Cursor gradient effect**: soft hover gradient on the compact shell, expanded views and Control
   Center. Idle-silent; measured against the baseline.
3. **Frosted-glass spike** (D-23): time-boxed prototype of real KWin blur with a shape-matched region.
4. **Widget architecture note**: formalise the existing `ActivityProvider` / `ModuleRegistry` into a
   widget contract (D-24, D-25); plan the `main.qml` breakup.
5. **First new widget**: Mirror or AI Agent Status.

## Unscheduled
- **N1: inline notification reply** via KDE's native reply action (only when the sending app offers
  it). Needs a keyboard-focus spike on the Wayland dock dialog first. Order relative to the quality
  pass is undecided.

## Backlog
- Known upstream issue, not fixed here: Firefox's MPRIS support is still maturing. After a seek on YouTube it drops `mpris:length` from its metadata update (we hold the last length for the same track and player, `MediaLength.js`) and then reports `Position` 0 until a pause or play, so the progress time sticks at 0:00. Related Firefox bugs: 1949425 (signals on position state changes), 1950461 (position advancing while paused), 1896774 (`mpris:length` only recently exposed). Seen on Firefox ESR, so the fixes may not have shipped there yet. A position workaround would guess wrong on a real restart from 0, so it is deliberately not done; revisit if Firefox keeps it
- Show a live notification's own actions (Reply, Mark as read, Mute) in the expanded popup; this is what will make mirrored KDE Connect notifications useful, since they have no default action
- Expired notifications can only open the app, not the exact chat: the chat target exists only as the live default action, which dies on expiry (Telegram, WhatsApp Web). Inherent to the notification protocol; revisit only if a sender exposes a URL
- Smart reply suggestions (parked: privacy and resource cost; candidate for a future opt-in AI widget)
- Notification queueing with "more waiting" indicator
- Project-wide icon migration to theme symbolic names (D-26), incl. `IslandButton` Canvas glyphs
- KDE Connect via its native QML module
- File shelf, system HUD, Bluetooth/USB events
- Release housekeeping: add maintainer to `metadata.json` authors (keep upstream credit), point
  Website/BugReportUrl at `groove`, README upstream/inspiration credits, own plugin ID/name
