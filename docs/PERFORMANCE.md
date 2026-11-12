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

Not re-measured after the changes: the Control Center while open (7.25% before; its bars now ride the same
8 fps clock, so it should be lower).

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
