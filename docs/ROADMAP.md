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
| Q2 | `main.qml` breakup (D-37): services, tested logic, `Strings.qml`, `shell/` components; per-file qmllint ratchet and probe | `17a85d1` ... `7571027` |

CC6 (notification list density/scrolling) was dropped.

## Now
- **B1, item 1 only:** the Light/Dark tile (findings reported; implementation waits for the maintainer's go, then a live
  test after the preferences are set and the theme files are backed up).
- Q2 final pass: the performance check against D-34 (idle and media), run when the maintainer is away, then the final report.

## B1: bug batch (done except item 1)
Found while moving code in Q2; behaviour was kept during the moves, then fixed one commit per item.
1. **Light/Dark tile applies stock Breeze and wipes custom setups.** *Open.* The tile flips `DarkModeControl.darkMode`, which
   applies `DefaultLightLookAndFeel` / `DefaultDarkLookAndFeel` from `kdeglobals [KDE]`, and those fall back to the stock
   Breeze packages when unset. Planned: read the preferences; if both are set toggle between those with
   `plasma-apply-lookandfeel --apply <package> --keep-auto` (no `--resetLayout`); if either is unset show a hint and open
   Global Theme settings; never apply a stock theme; state from `LookAndFeelPackage`, falling back to the Qt colour scheme.
2. **Quote the KDE Connect device id** in "browse". *Done* (`f64e3aa`): both commands built by `KdeConnectState.deviceCommand`,
   tested through a real shell with 14 hostile ids.
3. **Mute with no default sink.** *Done* (`c6aa870`): calls `globalMuteSinks` (outputs only), tested with stubs.
4. **Volume display above 100 %.** *Done* (`54ac49f`): the reading runs to 150, checked on the real tile at 100-125-150.
5. **Notification priority (D-38).** *Done* (`34b653a`): explicit urgency mapping, new order, Low is not an activity.
6. **Media player selection (D-39).** *Done* (`55b6732`): explicit filter and sort keys, most recently started wins, all
   players seen.

## Next
1. **Cursor gradient effect**: soft hover gradient on the compact shell, expanded views and Control
   Center. Idle-silent; measured against the baseline.
2. **Frosted-glass spike** (D-23): time-boxed prototype of real KWin blur with a shape-matched region.
3. **Widget architecture**: Q2 produced the services and logic layers (D-37); formalise them, together with
   `ActivityProvider` / `ModuleRegistry`, into the widget contract (D-24, D-25).
4. **First new widget**: Mirror or AI Agent Status.
5. **What is left of the quality work:**
   - Lint warnings: 471 remain (the baseline is per file, `.github/qmllint-baseline.txt`), almost all in the Control Center
     tiles and a few views; move their translated text into `Strings.qml` the way `main.qml` did and give the views
     required properties, then lower the baselines.
   - Performance follow-ups (see `docs/PERFORMANCE.md`): re-measure the Control Center while open; the "idle for 5 minutes"
     pause once an event-driven idle source exists for QML; `IslandButton` Canvas glyph repaints.
   - Not covered by tests yet: the click versus double-click discrimination (it lives in `IslandCompact` and `main.qml`'s
     click timer) and weather caching.

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
