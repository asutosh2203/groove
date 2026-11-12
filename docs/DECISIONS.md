# Decisions

Design principles and the decisions register for Dynamic Island for KDE Plasma. Newest entries at
the bottom. Status is **Accepted** unless noted. Superseded entries stay, marked as such.

This project is a fork of [Manu028's kde-plasma-dynamic-island](https://github.com/manu028-727/kde-plasma-dynamic-island)
(GPL-3.0-or-later), inspired by [TaqsBlaze/notched](https://github.com/TaqsBlaze/notched),
DynamicNotch and NexNotch.

## Design principles
1. **One shell, two appearances.** Dynamic Notch and Dynamic Pill are presentation modes of the same
   product, not separate widgets with duplicated logic.
2. **Fixed anchor, independent expansion.** The panel supplies a stable compact shell; expanded
   content renders in a separate Plasma dialog instead of resizing the panel.
3. **Activity-first behaviour.** Media and notifications temporarily replace idle content.
   Notifications pre-empt media; media returns afterwards.
4. **Preserve proven interactions.** Click, double-click, click-outside dismissal, media switching and
   notification lifecycle stay stable unless a change is agreed.
5. **Native KDE/Qt infrastructure first.** Prefer Plasma and Qt services (D-Bus, QML modules) over
   shelling out or native helpers.
6. **Polish through composition, not decoration.** Shared geometry, spacing and alignment over ornament.
7. **Development-only iteration.** Validate in a development install; production stays untouched until
   a change is accepted.
8. **Collaborative decisions.** Implementation is driven by investigation; design and scope decisions are
   made through review of findings, screenshots and trade-offs.
9. **Lightweight by default.** When nothing changes, nothing renders. No background subprocesses while
   idle. Every timer and animation has a stop condition. Beauty never at the cost of stutter.

## Register

| ID | Decision | Rationale / note |
|---|---|---|
| D-01 | Support Dynamic Notch and Dynamic Pill | Two user-selectable modes sharing one engine |
| D-02 | Fixed compact allocation (~180×40) | Avoid panel resize/recentring during animation |
| D-03 | Panel as anchor; independent dialog for expansion | Can't draw outside a Wayland panel surface without resizing it |
| D-04 | Notch panel non-floating; Pill panel floating | Required physical positioning difference |
| D-05 | Preserve original panel settings when switching modes | Never permanently alter the user's Plasma setup |
| D-06 | Notch: flush top, subtly curved shoulders, rounded lower corners | Integrated display-notch silhouette |
| D-07 | Idle shows time and weather | Useful ambient state instead of an empty shell |
| D-08 | Weather location is chosen manually | No GPS or IP-inferred location |
| D-09 | Open-Meteo as weather provider | Keyless, free for non-commercial use |
| D-10 | Bundled Meteocons Monochrome; motion rebuilt in QML | Qt's SVG renderer doesn't animate SMIL and drops some masks |
| D-11 | Medium icon weight (~+25% stroke, `#D1D3D8`) | Small-size legibility |
| D-12 | Time click → calendar; weather click → forecast; double-click → Control Center | Useful idle interactions |
| D-13 | Notifications pre-empt media; media returns afterwards | Activity continuity |
| D-14 | Mute is system-wide (default sink), not per-player | MPRIS has no mute; stream matching is unreliable |
| D-15 | Expanded media artwork follows the inner shell corner | Artwork reads as part of the shell |
| D-16 | Expanded notification popup uses fixed media-popup dimensions | Consistent footprint; content adapts inside |
| D-17 | Notification text limits: app 1 line, title 2, body 2 | Graceful handling without growing the shell |
| D-18 | Urgency dot: grey / green / red for low / normal / critical | Severity only, not unread state |
| D-19 | Control Center media controls sit below the artwork | Uses card width, preserves art size |
| D-20 | Control Center progress is read-only | No seek in the compact card |
| D-21 | Control Center notifications show relative timestamps | Original creation time, refreshed periodically |
| D-22 | Control Center styling reuses shared design tokens | Consistency without redesign |
| D-23 | Frosted glass deferred, not abandoned | Needs a reliable KWin/Wayland blur path; time-boxed spike first |
| D-24 | Customisation follows a phone-style widget catalogue | Enable/disable, reorder, presets, few settings; no freeform editor |
| D-25 | Built-in widget contract before third-party extensions | Stabilise API and permissions first; extensions must be GPL-compatible |
| D-26 | Icons resolve through the system icon theme by symbolic name | Respects the user's theme (e.g. WhiteSur, Breeze); bundle only what themes can't cover (weather). Always provide a fallback chain |
| D-27 | Integrations use D-Bus / machine-readable data, never human-readable CLI text | CLI output is translated and changes format; KDE Connect state comes from the daemon over D-Bus |
| D-28 | KDE Connect card: one empty state; paired-but-away devices shown dimmed ("Not nearby"); unpaired hidden; no scroll list, "+N more" opens KDE Connect; Ring + Browse on hover/focus | CC5 |
| D-29 | New logic ships with unit tests; decision logic lives in pure JS modules, QML executes | Testable without Plasma; slims `main.qml` |
| D-30 | CI runs on the current Active LTS Node (26), installed from the pinned Arch snapshot (D-36), and picks up every `tests/*.test.cjs` automatically | Node 20 is EOL; no hand-maintained test list; the version is printed in every CI log |
| D-31 | Notification click fallback chain: live default action → URL → app desktop entry (only if launchable; NoDisplay entries don't count) → not clickable. A successful open dismisses the notification everywhere and closes the Control Center/popup. Expanded popup opens on single click anywhere on the island. Clickable items get a hover highlight and pointer cursor (no tooltip). The right-hand slot of a notification's top line shows the age at rest and cross-fades to the open glyph and dismiss cross on hover or keyboard focus (same size and muted colour, no layout shift); non-clickable items show only the cross. Hovering (or focusing) an activity popup freezes its lifetime timers, which finish with the time left on release | CC7. An expired notification can only open the app, not the chat, because the chat target is the live default action. A notification with nothing to open (e.g. KDE Connect mirrors: no default action, no URL, NoDisplay daemon entry) stays non-clickable; no consolation target such as opening the KDE Connect app |
| D-32 | One app launcher for desktop entries: activate an existing window through Plasma's `org.kde.taskmanager` TasksModel (matched by app id or launcher file), else `kioclient exec <desktop file>`, else `gtk-launch` | Measured live on Wayland: relaunching a desktop entry (`kioclient exec`, `gtk-launch`, `gio launch`, D-Bus `Activate`, a `tg://` URL) did not un-minimize a tray app (Telegram), because it carries no activation token. plasmashell is KWin's trusted shell, so `requestActivate` on the task model raises and un-minimizes it. The model is created only while a launch looks for a window. Used for the notification fallback and the calendar |
| D-33 | Notification popup duration: the user's setting S shortens to the app's own timeout T when 0 < T < S (2 s floor); T >= S, -1 (server default) and 0 (never expires) use S; critical urgency is at least 6 s and never above 15 s. One value drives both the popup timer and the notice lifetime timer. Hover or focus still pauses it (D-31) | Apps know how long their message matters, but must never keep the island up longer than the user chose. Urgency is KDE's enum (Critical = 4) |
| D-34 | Performance budget: idle with nothing animating costs about 0%; an animating weather icon at most 0.5% added; media playing at most 1%; the Control Center may spike but returns to idle levels when closed. All decorative loops (weather icon, AudioBars, Control Center bars) run from one shared 8 fps clock that only ticks while an item holds a lease, and pause while a fullscreen window covers the island's screen (event-driven, through the task model). No polling. Lock and screen-off need no rule: the compositor stops frame callbacks. The 5-minute user-idle pause is not implemented: no event-driven idle source exists for QML. The 4x MSAA shape layers stay | Measured in docs/PERFORMANCE.md: a continuously animating item redraws the panel at the display rate for about 5% CPU, so decorative motion has to be throttled and has to stop when nobody can see it. The Shapes CurveRenderer was tried instead of the layers and used more memory |
| D-35 | When a media player exists but nothing has been playing for 30 s, the island returns to the idle face (clock and weather); anything that starts playing takes media back immediately | A paused player that merely exists kept the media pill forever, so the clock and weather never came back while Spotify was open. The decision lives in MediaIdle.js (tested); QML only runs a single-shot timer |
| D-36 | CI environment: one job in a pinned Arch Linux container (`archlinux/archlinux:base-YYYYMMDD.0.N`) with pacman pointed at the Arch Linux Archive snapshot for the same date, so the base system and every package (Qt 6.12, Plasma 6.8, Node 26) are pinned together. All checks run in that job: Node tests, qmllint over a glob of ALL QML and JS under `contents/` (errors and `[import]` warnings fatal, the warning count may only go down: `.github/qmllint-baseline.txt`), the Qt Quick tests (offscreen, software backend) and the package build. The host runner is `ubuntu-24.04`. Dependabot bumps the actions weekly but does not touch the container image or the snapshot date | A dated image tag alone does not pin packages (`pacman -S` pulls today's repos), and Plasma's private QML modules change between releases, so the snapshot date is what makes CI reproducible and matches CachyOS. Failing on `[import]` warnings stops a broken package set from silently weakening every other check; the ratchet stops new warnings while the 677 "unqualified access" ones are paid down (Q2). Measured: the job takes about 2 minutes, so no package cache |
