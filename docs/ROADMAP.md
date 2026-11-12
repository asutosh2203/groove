# Roadmap

Last updated: 12 November 2026. Decisions referenced as D-xx live in [DECISIONS.md](DECISIONS.md).

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

CC6 (notification list density/scrolling) was dropped.

## Now
- **CC7: notification click-through** (D-31). Control Center list and expanded popup.

## Next
1. **Quality pass**
   - Performance baseline: plasmashell CPU, memory and repaint rate for widget off / idle / media /
     Control Center open. Then fix hot spots: always-on idle weather animation, unread pulse loop,
     `layer`/`MultiEffect` usage, `IslandButton` Canvas glyph repaints.
   - Test coverage: extract and test logic still inside `main.qml` (activity priority/pre-emption,
     media player scoring, urgency mapping, click/double-click, weather caching).
   - CI gaps: `contents/ui/weather/*.qml` and `weather/*.js` aren't syntax-checked; Qt Quick
     tests don't run in CI.
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
- Smart reply suggestions (parked: privacy and resource cost; candidate for a future opt-in AI widget)
- Notification queueing with "more waiting" indicator
- Project-wide icon migration to theme symbolic names (D-26), incl. `IslandButton` Canvas glyphs
- KDE Connect via its native QML module
- File shelf, system HUD, Bluetooth/USB events
- Release housekeeping: add maintainer to `metadata.json` authors (keep upstream credit), point
  Website/BugReportUrl at `groove`, README upstream/inspiration credits, own plugin ID/name
