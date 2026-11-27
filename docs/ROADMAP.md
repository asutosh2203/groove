# Roadmap

Last updated: 26 November 2026 (everything below up to L3 is merged into `main`). Decisions referenced as D-xx live in [DECISIONS.md](DECISIONS.md).

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
| B1 | Bug batch (see below) | one commit per item, see below |
| D1 | Deck shell: deck, page-control capsule, Live page with job tiles, list and accordion, content-aware Live glyph (D-51 to D-53); closed-deck check in `docs/PERFORMANCE.md` ("After D1") | `cdde11c`, `83c4c12`, `1612008`, `c316c16` |
| D2 | Widget host, manifest registry, versioned presets, minute-tick clock service, Clock, World Clock, Weather; contract v1 (D-54, D-55). Presets came from the hidden `devPresets` key; `deckDummyPages` is retired | `d1ad2cb`, `08a8f96` |
| D3 | Preset editor: one edit mode from the Control Center's pencil, grid, catalogue sidebar, manifest-generated settings form, chips bar, transactional session (D-56). A first pass to live with | `4c23e62`, `75d3086` |
| D4 | Capsule scrub: press and drag across the page-control capsule; `scrubDwell` is 120 ms because pure live (0) lurched through every page (D-62) | `ea47584`, `6049485` |
| W2, W2.1 | Agents as a native Live activity, then command timer, exact-sleep countdown and subagents (D-57, D-58) | `9102387`, `338f7c5`, `5134add`; `50d82ab`, `5f07753` |
| N1 | Inline notification reply shelf (D-43, D-44). Live-checked in Notch and Pill with a D-Bus test sender (`tests/tools/`); a real Telegram or KDE Connect check needs a test conversation | `08e7a36` |
| L1 | Claude Code widget: budget and outcomes, 1x1 and 2x1, opt-in status-line helper (D-60, D-61) | `5ccbd7a` |
| T1 | Token pass on the top findings of `docs/TOKEN-AUDIT.md`, plus a token ratchet (D-47) | `ca53642`, `38738f3` |
| L2 | Pomodoro widget: `timer` service, 1x1, 2x1 and 4x1 views, Live tile, closed-capsule rank, phase-end pop-in, Do Not Disturb during focus, Kove pop-ins respect DND, form rework and enum labels (D-64). Timers are in memory only (persisting them is in Ideas). Merged as PR #7 | `4bdf9f6` |
| Media | Elapsed time, seeks, live streams and the polling gate (D-63). Merged as PR #8 | `86039a4` |
| L3 | System Monitor widget: `sysmon` hub on KDE's sensor framework, two-minute history, 1 s visible and 5 s hidden cadence, off while locked, 1x1, 2x1 and 4x1, hot level with hysteresis, tinted smoothed sparkline, enum picker page for every enum, optional hot alerts, contract's `spans` field key and option availability (D-65). Merged as PR #9 | `ccb4480` |
| Tour | First-run welcome tour: a Wide Welcome page with a five-card stepper (Skip, Back, Next, Done), shown once per tour version (`tourVersion`), replayable from the widget settings; opt-in "Essentials" example page built from the editor's own steps (D-69) | this branch |
| Disc | Pill disc spin: the compact artwork turns while music plays (10 deg/s on the shared 8 fps clock), held angle in a media-service state object, ring hub; variants A to F10 measured, D and E rejected on cost (D-68) | this branch |

CC6 (notification list density/scrolling) was dropped.

## Now
- Release prep: see "Before the first public release" below.
- Follow-ups of the finished deck and widget work (the milestones themselves are in the Done table):
  - D3 is a first pass to live with: use the editor for a few days, then refine. The one starter page is the tour's opt-in "Essentials" (D-69).
  - Possible later for the editor: right-click a preset page to edit that preset (a shortcut; the capsule stays symmetric,
    D-51); a catalogue search; keyboard reordering; an `app` field type when a widget needs it.
  - L3 not verified live: the middle of the 300 ms tint fade, the sustain reset on dropping below the exit threshold, a lock of over
    a minute while hot, and the picker with a real pointer beyond what was tried. L2's "not verified live" list was never closed out.
  - 2 to 4 option enums (weather units and detail, clock time format) now use the picker too; the one-line switch back to
    segmented is `FormModel.controlFor`.

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
   Confirmed by Asutosh in daily use on 26 Nov 2026.

## Next
1. **Frosted-glass spike** (D-23): time-boxed prototype of real KWin blur with a shape-matched region.
   - A small native C++ helper could provide both blur-behind (`KWindowEffects`) and input-region trimming (`QWindow::setMask`, which would remove the click-swallowing reply strip, D-43).
2. **What is left of the quality work:** (the widget contract is built, D-54, and the token pass is done, T1 in the Done table)
   - Lint warnings: the per-file baseline (`.github/qmllint-baseline.txt`) sums to 454, almost all in the Control Center
     tiles and a few views (a local qmllint currently counts 478, see `docs/CI.md`); move their translated text into
     `Strings.qml` the way `main.qml` did and give the views required properties, then lower the baselines.
   - Performance follow-ups (see `docs/PERFORMANCE.md`): the Control Center while open is measured (0.97%, see the Q2 section); the expanded media popup is re-measured (G1); still to re-measure: the notification popup, Pill mode; the "idle for 5 minutes"
     pause once an event-driven idle source exists for QML; `IslandButton` Canvas glyph repaints.
   - Not covered by tests yet: the click versus double-click discrimination (it lives in `IslandCompact` and `main.qml`'s
     click timer) and weather caching.

## Before the first public release
- **Naming (D-66, D-67): renamed to Kove** (plugin ID `io.github.asutosh2203.kove`, name, URLs, authors, panel preset, release file name). Left for release time: the version number. The icon is done: `contents/icon.svg`, referenced as `"Icon": "/icon.svg"` in `metadata.json` (a path inside `contents/`; seen working in the Widget Explorer on Plasma 6.8.3, and the About page needs Plasma 6.7 or newer).
- **KDE Store listing** as an explicit release step: description, screenshots and categories (also in `RELEASE_CHECKLIST.md`).
- **Manifest i18n pipeline** (see Backlog): export the widget manifests' translatable text to the catalogue and back.
- **Hybrid-laptop check:** with the GPU sensors subscribed, confirm the discrete GPU still runtime-suspends in offload mode.
  Not applicable on the development desktop, where the RTX 4060 drives the display (D-65 measured it `active` either way).

## Widget library

### Design notes
Full design in [`WIDGET-ARCHITECTURE.md`](WIDGET-ARCHITECTURE.md): the deck ([Live] -> presets -> [Control Center]), the
cell-span grid (D-48), the preset editor, ref-counted services, the widget contract and persistence. Still open there:
context-aware presets and how third-party widgets would be isolated.

### W1 / W2: Claude Code integration
- **W1 (superseded):** hooks, a per-session daemon and notifications, with the work shown as a disguised KDE job (D-49). The
  job path is retired (D-57).
- **W2 (done): agents as a native Live activity (D-57).** One per-user aggregator on the session bus
  (`io.github.asutosh2203.Kove.Agents`); Kove subscribes from QML with no polling. Tiles for working, working with tasks,
  waiting and done; compact rows above the transfers in a busy list; the closed capsule and the Live glyph (media > agent >
  jobs); click-through by process chain and scope app id, never a guess; Kove's own icon set (`contents/ui/icons`).
  Checked live in Notch and Pill, with fake sessions and with a real Claude Code session.
- **W2.1 (done): richer agent tiles (D-58).** Command timer, exact-sleep countdown that takes the bar, subagents named on the
  tile, the closed capsule's "N min left"; timestamp-driven with a deadline-based aggregator and a Kove clock that only ticks
  per second while the deck shows a moving clock. Soak result: docs/PERFORMANCE.md "After W2.1".
  Follow-ups: accordion overlap and scroll-into-view fixes (D-53), working agents rank below media on the closed capsule (D-58),
  cover art cache (D-59).
- Deliberately deferred: approve/reject buttons on the waiting tile (they need a second channel into Claude Code).
- **Agents: tmux click-through.** A session running inside tmux has no window in its process chain, so its tile is not
  clickable. Add a tmux lookup (find the client's terminal window through tmux) so the click can raise it; keep the rule
  that nothing is guessed. The current limit is in `integrations/claude-code/README.md`.
- **L1 (done, merged): the Claude Code widget (D-60).** Budget and outcomes, 1x1 and 2x1, fed by an opt-in
  status-line helper that chains the user's original status line. Usage ring, spend mode for API keys, recent sessions in
  memory, hover peek, row and tile clicks. Soak: docs/PERFORMANCE.md "After L1".
- Future note only: other agents (Codex, Aider, Gemini CLI, ...) via small adapters. The island side is agent-agnostic; the
  aggregator would need an agent-neutral event next to Claude Code's, then one adapter script per tool.

## Backlog
- **Contract v2: interactive 2×2 widgets (Tall page only).** Actions go through services (a widget never runs commands),
  scrolling and text input are allowed inside a 2×2, and risky actions ask for confirmation. Not started; logged so it is not
  forgotten (v1 widgets are plain clicks only). **First widget on v2: a Claude Code 2×2.** It would be the first widget that
  needs v2's interactivity; a v2 decision entry comes when it is designed, not before.
- **System Monitor sparkline: try `ShapePath.strokeGradient`.** A gradient stroke could replace the single tint colour. Measure
  its render cost against the current line (`CurveRenderer`, `Sparkline.qml`) before adopting it; keep the current look if it
  costs more than a measurable amount of CPU.
- **Map the gateway `spend_limit` onto the ring.** Behind a Claude gateway the status line carries
  `rate_limits.spend_limit` with real `used_usd`, `limit_usd` and `period`. L1 treats that setup as spend mode; the ring could
  show the real percentage and the detail "$12 of $50 · resets Mon" instead of the estimated cost.
- **Known limitation: usage outside terminal sessions.** Plan usage reaches the widget only through the terminal status line, so
  VS Code-only (or other front-end) users see no ring; the widget keeps and ages the last value and says where usage comes from.
  There is no supported source today (D-60 research); revisit when Claude Code exposes `rate_limits` to hooks or the extension
  (the aggregator already accepts it from any hook payload). Do not read the OAuth token.
- **Settings form scrolling: not needed (D-56).** The form fits its rows and the registry caps a manifest at eight fields, so
  it never scrolls. Revisit only if a widget needs more.
- **Align the idle face's weather icons with the widgets.** The panel's idle face still draws the bundled, colour, animated
  Meteocons; the Weather widgets draw monochrome white glyphs (theme `weather-*-symbolic` first, D-55). Decide whether the idle
  face should use the same glyphs (and drop its animation) so the two agree.
- **Pre-release: manifest i18n pipeline.** KDE's tooling will not extract translatable text from our custom widget JSON
  manifests (`name`, `description`, setting labels are locale-keyed objects with `en` only). Needs a step that exports them
  to the translation catalogue and back, before the first public release.
- **Scroll on the closed island (inherited from upstream; found by reading `shell/IslandCompact.qml` `onWheel`, not tested live).** (a) A horizontal-only wheel event has `angleDelta.y == 0`, so `angleDelta.y > 0` is false and it lowers the volume. (b) Every wheel event applies one full step (0.04 for a player, one `volumeUp`/`volumeDown` for the system) whatever its size, so a touchpad that sends many small events may change the volume very fast. Normal vertical scroll for volume and middle click for play/pause work (confirmed by Asutosh, 26 Nov). Possible fix: ignore `y == 0` and accumulate the delta per step.
- **Pill on a fresh install can sit flush against the top edge (design question, touches D-05).** Pill only acts on the panel when the original settings are stored (`panelOrigPanelId`, `panelOrigFloating`); a clean config has none, so `PanelPlan.decide` leaves an attached panel as it is and the pill is glued to the bezel. Switching to Notch stores the originals, and Pill then floats the panel. Open: should Pill float the panel by itself when nothing is recorded, for a new user with an ordinary attached top panel? Not decided, not urgent.
- **Two QML warnings in the journal (not diagnosed; a small bug batch after release prep).** (a) `shell/editor/SettingsForm.qml`: "Cannot read property 'control' of undefined" in the FormRow delegate's `form.model.fields[fieldRow.modelData]` bindings; likely a delegate reading the fields array before it updates when the form's model switches. (b) `shell/PopupContent.qml` "Binding loop detected for property noticeClickable" on the notice row's `MouseArea` (it reads `app.notifications` and `popupMode`).
- **Deck opened over an already open popup gets a page-sized window (pre-existing, found live during the tour check, not fixed).** `openIsland` sets `deckWindowActive` only when the island was not open (`!wasOpen`), so a deck opened while an activity popup is showing keeps the popup's window: the deck is clipped to a 120 px window and the page-control capsule, which sits below the island, is cut off (D-43 pre-sizing is skipped). Seen live when a debug timer called `showDeck` over a Claude Code "Done" pop-in; the expected user repro, read from the code and not tried by hand, is a double click on the island while a notification pop-in shows (`showControlCenter` goes straight to `showDeck`), while a single click closes an open island first. Possible fix: set `deckWindowActive` whenever `mode === "deck"`, or close the popup first; check that it does not resize a visible window (D-43).
- Glow 60 fps cap ready on `perf/glow-60fps`; needs a real-pointer before/after measurement.
- Reply shelf: multi-line input (v1 is a single line); host the notification's other actions (Mark as read, Mute) in the shelf.
- **Native popup coexistence:** detect whether Plasma's own notification popups are active; never change it automatically (D-05). Show a one-time dismissible hint and a permanent note in settings with an "Open notification settings" button; document in the README. Investigate the officially supported way to disable Plasma popups without stopping the notification server. The island respects Do Not Disturb since D-64 (no pop-ins while DND is on, critical still pops).
- **Enhancement (low priority, revisit before a public release): icon fallback chains for the Control Center tiles (D-26).** Tiles tint glyphs as flat masks, so a theme that lacks a `-symbolic` name (or draws it in colour) shows a blob or nothing. Give each tile an ordered list of names (symbolic, then an alternative symbolic, then a plain icon drawn unmasked) and test with Breeze and Adwaita. Today only the Theme settings tile has a fallback, and `Tokens.js` `symbolic()` maps names to Breeze-style symbolics.
- The old "Theme" tile is retired from the editor palette (it opened the same page as "Theme settings"); the id stays known so saved layouts keep it.
- Firefox's MPRIS support is still maturing (D-63). On YouTube it drops `mpris:length` and reports `Position` 0 a few seconds into a video until a pause, a seek or a speed change. Handled in the island: the last length is held per track (`MediaLength.js`), the position is estimated from the last known one at the player's `Rate` (`MediaPosition.js`), and with no length at all the expanded view shows the elapsed time alone. Hover previews on the YouTube home page are hidden by reading `xesam:url` over D-Bus. Seeks while playing are re-anchored from the `Seeked` signal. A live stream has no length and is not detectable over MPRIS, so it shows the elapsed-only view (no Live badge). Open: the no-length, non-live elapsed view has not been seen live. Related Firefox bugs: 1949425 (signals on position state changes), 1950461 (position advancing while paused), 1896774 (`mpris:length` only recently exposed). Seen on Firefox ESR, so the fixes may not have shipped there yet.
- **Intermittent bug: expanded media view loses its progress bar and time labels (open, not diagnosed).** Seen 2026-11-17 with Spotify playing (Comfortably Numb): the bar and both time labels were gone, so `media.length` read 0 in `MusicExpanded` (`hasLength`). Spotify reported `mpris:length` correctly over D-Bus, and after a plasmashell restart the dev copy read it correctly (`MediaService` log: role, held length and `length` all 382280000), so it is not a startup or role problem. Suspect a state change after startup (track change or seek: a metadata update without length, then `MediaLength.hold` keeping 0 or a refresh that never re-runs). To catch it: add a `console.warn` in `MediaService.refreshLength()` that logs `player.length`, `heldLength` and `length`, wait for it to happen, read the journal. Not reproduced yet.
- **Won't do: Spotify shows only the first artist (2026-11-17).** For "Fire on the Water" Spotify's window lists "Bonobo, Arooj Aftab", but its MPRIS `xesam:artist` array has one entry (`Bonobo`), so the island and Plasma's MPRIS model show exactly what Spotify publishes. Spotify drops featured artists from MPRIS for some tracks. The only workaround is a lookup in Spotify's own API, which needs a network dependency and a sign-in, so it is deliberately not done. Checked for this one track only; how other players that send several artists are joined by Plasma's model was not checked.
- README: Firefox downloads appear in the island only with the Plasma Integration browser extension and the `plasma-browser-integration` package installed; without them Firefox reports no job to KDE.
- Show a live notification's own actions (Reply, Mark as read, Mute) in the expanded popup; this is what will make mirrored KDE Connect notifications useful, since they have no default action
- Expired notifications can only open the app, not the exact chat: the chat target exists only as the live default action, which dies on expiry (Telegram, WhatsApp Web). Inherent to the notification protocol; revisit only if a sender exposes a URL
- Smart reply suggestions (parked: privacy and resource cost; candidate for a future opt-in AI widget)
- Notification queueing with "more waiting" indicator
- **C8: Wi-Fi and Bluetooth panels** (replaces Q4). Clicking the Wi-Fi or Bluetooth tile opens an in-island list instead of
  KDE settings: available networks or devices, connect and disconnect, signal strength, paired and connected state. Built on
  the native models (plasma-nm for Wi-Fi and networks, BluezQt for Bluetooth) in place of `nmcli` and `bluetoothctl` text
  parsing (D-27). The parsing and the "which line" decisions are already pure and tested (`Bluetooth.js`, `NetworkState.js`),
  so mostly the sources change. It absorbs two open items: the Bluetooth tile's "Discover" title (the tile is
  `bluetoothDiscovery`; it reads "Connected" or "Discover" by device count) and the Wi-Fi tile's empty gap between the header
  and the network name (`docs/TOKEN-AUDIT.md`). KDE Connect on its native QML module stays its own item below.
- Found during Q2 (behaviour kept): `PlasmaNM.WirelessStatus` is instantiated in `ConnectivityService` but never read;
  the inline `StatusChip` component was dead code and was deleted; `kdeconnect-cli`/qdbus ids are only quoted in the
  "ring" command (B1 item 2).
- Project-wide icon migration to theme symbolic names (D-26), incl. `IslandButton` Canvas glyphs
- KDE Connect via its native QML module
- File shelf, system HUD, Bluetooth/USB events

### Ideas, not committed
- A generic Live Activity D-Bus API for any script or app (generalising the agents protocol).
- A zsh hook that shows long-running shell commands (over 30 s) as live tiles with done pings.
- A GitHub Actions CI watcher tile.
- A Spectacle screenshot thumbnail in the island (drag, copy, annotate).
- Earbuds connecting, with battery (BlueZ).
- A charger plugged-in moment.
- KDE Connect incoming calls with mute-ringer.
- An Open-Meteo short-term rain alert.
- A next-meeting tile.
- Mic, camera and screen-share privacy dots (PipeWire).
- A global shortcut to open the deck, plus keyboard navigation.
- Preset export and import (later "preset packs").
- Multi-monitor islands.
- A small drawing per welcome-tour card (QML shapes plus theme or Kove icons, no live widgets), after the text-only tour (D-69).
- Pomodoro: keep timers across a plasmashell restart (persist deadlines).
- System Monitor: a per-disk and per-interface picker (dynamic enum options), a top-processes widget, a hover peek with the two-minute peak and average, fan and NVMe temperatures, and multi-GPU with a stable GPU choice (by name, not index: `gpu0` is the first the daemon lists).
- Agents: background tasks are mostly invisible. The Claude Code integration is hook-driven only (`install.sh` events; nothing in `kove_logic.py` or `kove_hook.py` mentions `run_in_background`). Foreground exact `sleep N` becomes a countdown (D-58). A background Bash command is tracked only from PreToolUse to PostToolUse, which for a background run ends when the tool call returns (inferred, not tested). Subagents come from SubagentStart/SubagentStop, so background ones probably show until they stop (not verified: D-58 only checked foreground ones, on Claude Code 2.1.325). A session shows done after Stop even if a background task still runs, and Monitor and scheduled wakeups show only for the instant of the call. Next step if wanted: a read-only investigation of what Claude Code emits for background shells and tasks (there may be no event for it) before any design.
- A Notch artwork spin, or another record idea for the Notch (not decided, D-68 keeps the Notch still).
