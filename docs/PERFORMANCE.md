# Performance

How the island's cost is measured, the budget it has to meet (D-34), and what was measured before and after the
Q1 work. All numbers are plasmashell CPU as a percentage of one core (all threads), unless noted.

## Method

`scripts/perf-baseline.sh <label> [duration=60] [runs=3]` samples plasmashell from `/proc` (process CPU time, busiest
threads, RSS) and, when present, `nvidia-smi`. It is read-only towards the system. Results go to the gitignored
`perf/results/`.

- **Frames per second:** `scripts/perf-baseline.sh frames-on` sets `QSG_RENDER_TIMING=1` in the systemd user
  environment and restarts plasmashell; Qt then logs one `syncAndRender: frame rendered` line per frame with the
  window it belongs to, and the script counts them from the journal. `frames-off` reverts it. Frame logging adds
  roughly 0.3-1.5% CPU, so CPU figures are quoted without it unless noted.
- **Machine:** CachyOS, Plasma 6.8.2 on Wayland, 1920x1080 at 165 Hz. plasmashell renders on the NVIDIA RTX 4060 (not
  the AMD iGPU). Every continuously animating item redraws at the display rate, so one animating item costs about
  0.06% CPU per frame per second, roughly 5% at 100 fps.
- **Conditions:** wait about two minutes after a plasmashell restart before measuring (start-up churn inflated
  early numbers). Hold a screen-saver inhibit for long unattended runs, or the idle lock blanks the screen and
  every state reads zero. Do not restart plasmashell more than a few times in ten seconds (systemd refuses).
- **Debug tooling** (a command poller and state overrides in the deployed dev copy) was throwaway and is not in the
  repository.

## Budget (D-34)

| State | Budget (CPU added to plasmashell) |
|---|---|
| Idle, nothing animating | about 0%; only the clock tick repaints |
| Idle, weather icon animating | at most 0.5% |
| Media playing (AudioBars) | at most 1% |
| Control Center open | may spike; must return to idle levels after closing |

## Baseline (before Q1)

| State | CPU | Frames/s |
|---|---|---|
| Idle, nothing animating (paused media pill, or idle face with a static icon) | 0.13-0.23% | 0 |
| Idle weather icon animating | about 5-6% (6.1-6.9% with frame logging) | 92-100 |
| Media playing, compact AudioBars | 5.42% | about 100 |
| Expanded media popup | 10.0% | about 100 in each of two windows |
| Notification popup held, unread notification | 4.57% | about 100 |
| Control Center open | 7.25% | n/a |
| Control Center closed again | 0.19% | 0 |
| Fullscreen window on top (media playing) | unchanged from playing | n/a |

Findings: any infinite animation redraws the whole panel at the display rate; the unread pulse, the AudioBars, the
weather icon and the progress bar's per-tick width animation all did it; and nothing paused under a fullscreen
window.

## After

| State | Before | After |
|---|---|---|
| Notification popup held, unread (finite pulse) | 4.57% | 0.17%, no frames |
| Media playing, position poll gated and per-tick animation removed (bars frozen to isolate it) | 1.33% | 0.27% |
| Media playing, compact, bars on the 8 fps clock | 5.42% | 0.67% (9 fps); 0.87-0.90% with real Spotify |
| Idle weather icon animating on the 8 fps clock | about 5-6% | 0.60-0.62% (8.0 fps), 0.45% above idle |
| Expanded media popup | 10.0% | 1.20% (10 fps: popup 9, panel 1; frame logging on) |
| Media playing under a fullscreen window | 0.87% | 0.22%, no frames |
| Cost of keeping the fullscreen task model alive (static idle) | 0.30% | 0.33% (noise); RSS +14 MB |
| Screen locked | n/a | 0.0-0.2 fps, no rule needed |
| Screen off (DPMS) | n/a | 0 fps, no rule needed |

## After Q2 (2026-11-14, after the main.qml split into services and logic, D-37)

Same method, median of 3 runs of 60 s, Spotify at 8% volume for the media states, a browser playing YouTube in the
background (the Q1 numbers were taken without it).

| State | Runs | Median | Budget (D-34) |
|---|---|---|---|
| Idle face, weather icon animating | 0.50-0.64% | 0.52% | at most 0.5% added over idle: met (about 0.3-0.4% added) |
| Media playing, compact | 0.92-1.42% | 1.23% | at most 1% added: met (about 0.7% added) |
| Control Center open, media playing | 0.80-1.00% | 0.97% (7.25% before Q1) | may spike: it does not |
| Control Center closed again, media still playing | 0.88-1.20% | 0.88% | returns to the playing level: met |

- Q2 added no idle cost: idle matches the Q1 figure (0.60%).
- The Control Center check Q1 skipped is now done. Its bars ride the shared 8 fps clock, so opening it costs about the
  same as plain media playback.
- Media playing read about 0.3 points above the Q1 real-Spotify figure (0.87-0.90%). The runs spread 0.92-1.42% and
  the background video was not present in Q1, so this is most likely noise or load; it was not isolated.
- Caveats: whole plasmashell on one machine, differences under about 0.3 points are not meaningful, frames per second
  were not measured, and the closed-again state was measured with media still playing (not against the idle 0.52%).
- Still not re-measured: the expanded media popup, the notification popup, Pill mode, the fullscreen-cover state.

## After G1 (2026-11-15, cursor glow, D-41)

Main at `4990889`, frame logging on (`frames-on`), Spotify playing at 8% sink volume, nothing else playing. Medians of
2 runs of 40 s (idle and moving: 1 run of 40 s and 28 s). The expanded media popup was held open with a temporary
debug hook (not in the repository), because any media event restarts its auto-close timer.

| State | CPU | Frames/s | Budget (D-34) |
|---|---|---|---|
| Idle face, weather icon animating | 0.50% | 8.0 | at most 0.5% added over idle: met |
| Compact, media playing | 0.64% (0.63, 0.65) | 9.0 | at most 1% added: met (about 0.14 added) |
| Expanded media popup, no hover | 0.74% (0.72, 0.75, 0.75, 0.73) | 10.0 (popup 9.0, panel 1.0) | Q1 figure 1.20% at 10 fps: no regression |
| Popup, pointer resting (emulated) | 0.75% (0.72, 0.78) | 10.15 (popup 9.0-9.1, panel 1.0-1.1) | **zero extra frames** vs no hover |
| Popup, pointer moving (emulated) | 7.26% | 101.8 (popup 101.1) | within the D-41 carve-out; only while moving |

- **Resting pointer costs nothing:** the glow settles and its frame animation stops, so the popup window stays at the
  media popup's own 9 fps. A control run of the no-hover state after the resting one read the same (0.74%, 10.0 fps).
- **Moving pointer:** about 6.5 CPU points above the popup at rest, and about 100 frames per second in the popup window,
  for as long as the pointer moves; it returns to the resting figures once the glow has caught up (about 0.4 s).
- **Emulation caveat:** the pointer states are emulated. A debug override feeds the glow component a constant point
  (resting) or a point on an ellipse updated every 16 ms (moving); no real pointer was used, so the `HoverHandler` and
  `PointHandler` plumbing was not exercised, and neither was Pill mode. The glow's own frame behaviour (fade, follow,
  settle, stop) is what the numbers describe.
- **Invalid earlier runs, not used:** a first run found the popup closed in the pointer states (a media event had
  restarted its auto-close timer); a second showed an extra 5.3 fps window and 1.78% in the resting state while the
  sink volume was being changed by hand (most likely the volume OSD; it did not recur with a constant volume); a
  third had no media playing. Their raw files are in `perf/results/` (`g1-*`, `g1b-*`, `g1c-*`; the valid ones are `g1d-*`).
- Still not measured: Pill mode, the notification popup, the Control Center with the glow (it shares the component),
  and a real pointer.

## After D1 (2026-11-17, the deck and the capsule, D-51 to D-53)

Dev copy on Plasma 6.8.2 / NVIDIA RTX 4060, Spotify playing the whole time (checked before and after), nothing else
active, machine untouched. Each state is 3 runs of 30 s, settled 120 s after a plasmashell restart, no frame logging.
The pre-D1 build is `5e0aaa4`; the others are HEAD. Raw files are in `perf/results/` (`*d1c-*`).

| State | CPU per run | Median | GPU util per run |
|---|---|---|---|
| Before D1, compact media pill | 0.73, 2.00, 1.48% | 1.48% | 11, 16, 27% |
| After D1, deck closed, compact media pill | 1.19, 1.30, 2.23% | 1.30% | 33, 30, 18% |
| After D1, deck open on Live (media card) | 0.97, 0.93, 0.94% | 0.94% | 40, 35, 32% |

- **No closed-deck regression:** the two closed-deck medians (1.48% before, 1.30% after) sit inside the run-to-run spread
  (0.7 to 2.2%), so the deck costs nothing measurable while closed (principle 9). An earlier pair of single 30 s runs
  (0.67% before, 1.60% after) was noise. One later change helps: the Live page's job details are only built while the
  deck shows.
- **Deck open:** about 0.94% with the media card visible, below the closed figure because the compact pill and its audio
  bars are hidden while the island is open. Frames per second were not measured, and a page morph, the capsule fade and
  a running job list were not measured.
- **Against the baselines above:** these totals (0.9 to 1.5%) are higher than the G1 compact-media figure (0.64%, taken with
  frame logging on and a different desktop load), for the old build as well as the new one, so the difference is the
  machine's current load and not D1. The media-playing budget (D-34, at most 1% added over idle) cannot be judged from a
  total without an idle run; none was taken here.
- **GPU:** utilisation readings (11 to 40%) vary by run with the card's clock state (P5 to P8) and show no trend.

## After D2 (2026-11-17, the widget host and the first widgets, D-54 and D-55)

Dev copy, Plasma 6.8.2 / NVIDIA RTX 4060. **Spotify and Firefox were paused for every run** (checked), so these are not
comparable with the "After D1" table, where Spotify was playing. Each state is 3 runs of 30 s, settled 120 s after a
plasmashell restart, no frame logging. The D1 build (`c316c16`) was re-measured the same way for a fair A/B. Raw files:
`perf/results/*d2-*`.

| State | CPU per run | Median | RSS |
|---|---|---|---|
| D1 build, deck closed (media paused) | 0.50, 0.50, 0.50% | 0.50% | 627 MB |
| D2 build, deck closed (media paused) | 0.50, 0.45, 0.50% | 0.50% | 631 MB |
| D2 build, Small preset open (Clock + Weather 1x1) | 0.07, 0.07, 0.06% | 0.07% | 644 MB |

- **No closed-deck regression:** identical CPU, +4 MB RSS. Nothing from D2 runs while the deck is closed: no minute timer, no
  Clocks, no weather polling beyond the idle face's own.
- **Preset page open:** about 0.07%, because the compact pill is hidden and a static page repaints only when the minute turns.
  The deck was held open by a temporary reopen timer in the deployed copy (removed afterwards); it was confirmed open on
  screen. The hover peek, the other spans, a page morph and frames per second were not measured.
- **Clock timers:** each Plasma `Clock` holds its own minute-aligned timerfd. Small preset: 1 (local). Tall sample: 3 (local,
  New York, Tokyo). Closed deck: 0 (the Clocks exist only while subscribed plus the 30 s grace).

## After D3 (2026-11-18, the preset editor, D-56)

Closed-deck A/B on the dev copy, 3 runs of 30 s each, settled 125 s after a plasmashell restart, no frame logging, D2 build
(`08a8f96`) and D3 build measured back to back. **Spotify was playing for both** (not paused: it is the user's music), so
these numbers are higher and noisier than "After D2" (media paused) and must only be compared with each other. Raw files:
`perf/results/*d3-ab-*`.

| State | CPU per run | Median | RSS |
|---|---|---|---|
| D2 build, deck closed (Spotify playing) | 0.65, 0.70, 1.07% | 0.70% | 662 MB |
| D3 build, deck closed (Spotify playing) | 0.53, 1.58, 0.63% | 0.63% | 698 MB |

- **No closed-deck CPU regression** within the noise (one run in each build spiked; the medians are 0.70 and 0.63%). Edit mode
  creates nothing while closed: its UI, the time zone model and the geocoding request exist only while it is open.
- **RSS: the +36 MB was noise (investigated 2026-11-18).** Six plasmashell restarts, each settled 100 s, deck never opened,
  Spotify playing, alternating the builds (D2, D3 as committed, D3 with the lazy-loading fix), two rounds:

  | Build | Round 1 | Round 2 | Anonymous (range) | File-backed |
  |---|---|---|---|---|
  | D2 | 665 MB | 666 MB | 215 to 221 MB | about 398 MB |
  | D3 as committed | 610 MB | 652 MB | 160 to 205 MB | about 398 MB |
  | D3 with the fix | 658 MB | 661 MB | 210 to 211 MB | about 398 MB |

  Restart to restart, anonymous memory swings by up to 55 MB for the same build (D3 as committed was the lowest and the
  highest D3 value in turn), and file-backed memory is the same everywhere, so no build is consistently larger.
- **Something eager did exist, and is fixed:** `PopupContent` named `EditPage` as a type, so all 14 editor QML files and the
  editor's pure modules loaded at startup (checked with `qt.qml.diskcache.debug`: 140 project files loaded, now 119). The editor
  UI is now loaded by URL through a Loader inside the edit-mode component, so it exists only while edit mode runs. Still always
  present: `PresetEditor.qml` and the pure modules `PresetEdit`, `PageFit`, `Catalogue` (the session state, which must outlive the
  deck to keep a draft). The private time zone module was already lazy (it loads with the first time zone field).
- **Through an edit session** (D3 build with the fix, one run, deck opened by a debug hook): closed 677 MB, deck open on the
  Control Center 684 (+7 to +12), edit mode on a Clock form, a World Clock form and the tile editor 683, 681, 681 (no
  measurable cost beyond opening the deck), closed again 682 after 5 s, 681 after 30 s, 692 after 60 s. **Memory is not given
  back after closing**: it stays about +5 to +15 MB over the first closed reading (malloc and the QML engine keep pages), and
  it does not grow with the number of pages visited. Not a leak by this measure (three forms and the tile editor in a row
  added nothing), but not released either.
- Not measured: CPU while edit mode is open (no media paused, and a held-open deck needs a debug timer).

## What changed (commits)

| Change | Commit |
|---|---|
| Baseline script | `f756d35`, `6fef95d` |
| Finite unread pulse | `61f123a` |
| Position polled only while visible, no per-tick animation | `e8dc61b` |
| Removed the unused inline `IslandBars` | `eecbf18` |
| One shared 8 fps clock for all decorative loops | `e4866a9` |
| Pause under a fullscreen window | `298c3a8` |
| Covered compact pill no longer repaints the panel | `8802d5d` |
| Idle face after 30 s without playback (D-35) | `68605e5` |
| Cursor glow (D-41): shader pipeline, expanded surfaces, settings toggles, Control Center stays put | `0184e1d`, `b59a6bd`, `cc482ff`, `4990889` |

## Lessons

- Even an invisible item schedules a repaint when one of its properties changes, so decorative bindings must stop
  evaluating while hidden, not merely fade out.
- Plasma keeps the compact representation's wrapper `visible` at opacity 0 while a popup covers it and overrides a
  `visible` binding set on it, so visibility cannot tell the pill it is covered; gate on `panelHidden` instead.
- Shape layers (`layer.enabled`, 4x MSAA) cost memory, not CPU. Switching the shapes to the Qt Quick Shapes
  CurveRenderer was measured and used more memory (Notch 645 to 716 MB, Pill 649 to 669 MB), so it was not shipped.
- Rendering stops by itself when the screen is locked or off (the compositor stops frame callbacks), so those
  states need no rule.

## Not done

- The "user idle for 5 minutes" pause: no event-driven idle source is available to QML here, and polling is not
  allowed. It is skipped until one exists.

## After W2.1 (2026-11-18, agent timer, countdown and subagents, D-58)

**Soak (60 min, `scripts/agent-soak.py`, raw: `perf/results/w21-soak.csv`).** A scripted fake session sent real hook events
through the installed `kove_hook.py`: a tool call every 2 to 5 s, an exact `sleep 60` every 10 min, a subagent started and
stopped every 3 min, the task list advancing every 2 min, a Stop and new prompt every 15 min. No real Claude. The deck was
closed except for one minute at minutes 5, 15, 25 and so on (a debug timer on the deployed copy, since removed). Spotify
was **paused** and nobody used the machine; the screen was asleep or locked for at least part of it, so the deck-open
minutes may cost slightly more on a lit screen. CPU is the average over the 5-minute window before the row.

| Minute | plasmashell CPU | plasmashell RSS | Aggregator CPU | Aggregator RSS | Log bytes |
|---|---|---|---|---|---|
| 0 | n/a | 619.1 MB | n/a | 33.6 MB | 336 |
| 5 | 0.20% | 634.9 MB | 0.02% | 33.8 MB | 336 |
| 10 | 0.07% | 639.7 MB | 0.01% | 33.8 MB | 336 |
| 15 | 0.17% | 639.0 MB | 0.01% | 33.8 MB | 336 |
| 20 | 0.08% | 639.3 MB | 0.01% | 33.8 MB | 336 |
| 25 | 0.14% | 648.2 MB | 0.01% | 33.8 MB | 336 |
| 30 | 0.11% | 648.4 MB | 0.01% | 33.8 MB | 336 |
| 35 | 0.15% | 649.5 MB | 0.01% | 33.8 MB | 336 |
| 40 | 0.08% | 649.5 MB | 0.01% | 33.8 MB | 336 |
| 45 | 0.13% | 649.1 MB | 0.01% | 33.8 MB | 336 |
| 50 | 0.08% | 649.1 MB | 0.01% | 33.9 MB | 336 |
| 55 | 0.11% | 649.5 MB | 0.01% | 33.9 MB | 336 |
| 60 | 0.09% | 648.6 MB | 0.01% | 33.9 MB | 336 |

- **Flat.** CPU has no trend (plasmashell 0.07 to 0.20%, median 0.11%; the aggregator 0.01 to 0.02%). The aggregator's RSS
  moved 0.3 MB in an hour and its log did not grow (the 336 bytes predate the soak). plasmashell's RSS stepped up about
  30 MB during the first 25 minutes, when the deck was opened for the first three times (QML components and the Live page
  load on first use), then held at 648 to 650 MB for the last 35 minutes, including three more deck opens.
- **Closed-deck idle A/B** (3 runs of 30 s, settled 125 s after a restart, media paused, no agent session): before W2.1
  (`c0c7b63`) 0.20, 0.16, 0.17%, median **0.17%**, 571 MB; after, 0.17, 0.16, 0.13%, median **0.16%**, 572 MB. No change.
  Raw: `perf/results/*w21-ab-*`. This also answers the open D1 question (0.67% to 1.60%): nothing runs while the deck is
  closed.
- **Found on the way:** an aggregator that outlives a plasmashell restart kept a proxy to the old Notifications owner and
  logged `notify: DBusException` for every later notification; it now creates the proxy per call.

## After L1 (Claude Code widget and status-line helper)

**Soak, 30 minutes** (`scripts/agent-soak.py 30`, raw `perf/results/l1-soak.csv`). One fake working session, with the installed
status-line helper called once a second for it (a real status line renders far less often, so this is the worst case for the
aggregator). Samples every 5 minutes; the first row has no CPU figure.

| | plasmashell | aggregator |
|---|---|---|
| CPU | 0.13 to 0.25%, mean 0.16% | 0.02 to 0.03%, mean 0.03% |
| RSS | 673 to 699 MB | 31.8 to 32.3 MB |

- **Flat.** The aggregator's RSS moved 0.5 MB in 30 minutes and its log did not grow. plasmashell's RSS rose about 26 MB, the
  same first-use step as in the W2.1 soak (QML loaded when a page is first shown), not a steady climb. Its CPU is in the
  range of the W2.1 soak (0.07 to 0.20%) with an agent session working the whole time. I did not run a closed-deck
  A/B for L1 (no timer or animation was added while the deck is closed: the widget's minute timer exists only while its page
  shows, and the sticky slot state is recomputed only on a snapshot).
- **The status-line helper** (`kove_statusline.py`, run by Claude Code on every render): 15.5 ms median, 16.4 ms p95, 17.3 ms
  max over 100 runs, against 5.9 ms for a bare `python3 -S`. About the same with or without an aggregator listening.
  It sends only when the numbers change, at most once per 2 s per session.

## After D4 (capsule scrub, D-62)
- **Closed-deck idle A/B** (3 runs of 30 s, 125 s after a restart, YouTube video PLAYING in the user's browser, so higher than
  the 0.16% media-paused figure of W2.1): before (HEAD) 0.43, 0.47, 0.50%, median **0.47%**, 653 MB; after 0.53, 0.45, 0.50%,
  median **0.50%**, 634 MB. Within noise. The scrub adds no timer or animation outside a scrub (the dwell `Timer` and the
  detent animation only start during one). Raw: `perf/results/*d4-ab-*`.

## After L3 (System Monitor widget, D-65)

All in one plasmashell process, 4 windows of 30 s per scenario (`utime + stime` from `/proc`, percent of one core, all threads), the user's
browser playing video the whole time (so kwin is high and every figure is higher than a quiet idle). The dev build carried a throwaway
debug poller (a `Timer` that reads a command file); its cost is measured below and is part of the (c) figure only because the deck had to be
held open. `ksystemstats` is shared with other subscribers.

| Scenario | plasmashell | ksystemstats |
|---|---|---|
| (a) no System Monitor placed, deck closed (0 `Sensor` objects, clock stopped) | **0.76%** (0.70 to 0.93) | 0.24% |
| (b) 4x1 placed (12 sensors), deck closed, 5 s tick, run 1 | 1.28% (0.70 to 1.83) | 0.25% |
| (b) same, run 2 | **0.77%** (0.67 to 1.03) | 0.24% |
| (b) same with the debug poller at 1 s (control for (c)) | 0.99% (0.70 to 1.53) | 0.24% |
| (c) deck open on the 4x1 page, 1 s tick | **1.72%** (0.97 to 2.70) | 0.25% |

- **Closed deck costs nothing measurable.** (b) run 2 equals (a); run 1 started right after the presets changed and is the sensors being
  created plus the first samples. The hidden 5 s tick reads 12 values and pushes a few arrays, and adds no animation.
- **Open deck: about +0.7% over the same state closed** (c against its control), for four graphs and four heroes updating once a second.
  The windows swing between 1.0 and 2.7% because the deck opening and closing is part of them (the auto-close brought it down once).
- **ksystemstats does not move** (0.24 to 0.25%) whether 0 or 12 sensors are subscribed from here: the other subscribers dominate.
  `updateRateLimit` thins QML events (240, 117 and 43 per 20 s at the default, 1 s and 5 s for 8 sensors) but not the daemon's D-Bus signals
  (84 each); only `enabled: false` removed our share.
- **GPU power state:** the NVIDIA card (`0000:01:00.0`) was `active` for 120 of 120 samples with no `Sensor` object and 120 of 120 with
  `gpu/gpu0/{usage,temperature,name}` subscribed, `runtime_suspended_time` unchanged (0 ms) in both. plasmashell and KWin render on it, so
  the sensors cannot be what keeps it awake and disabling them while the deck is closed would save nothing.
- Raw numbers: `~/os_setup/perf-l3/` (not in the repository).

**After the whole-graph tint and the enum picker page** (same method, 4 x 30 s): scenario (c), deck open on the 4x1 page, 1 s tick, with the debug
poller running at 1 s: plasmashell **1.68%** (1.00, 0.97, 1.23, 3.53; the last window includes a deck re-open), ksystemstats 0.28%. Before the change
the same scenario read 1.72%. The smoothed path and the fill gradient change the two path strings per sample and add no timer or animation outside
the 300 ms tint; the picker page exists only while the form is open.
