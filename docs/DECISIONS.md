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
| D-30 | CI runs on the current Active LTS Node (26) and picks up every `tests/*.test.cjs` automatically | Node 20 is EOL; no hand-maintained test list |
| D-31 | Notification click fallback chain: live default action → URL → app desktop entry → not clickable. A successful open dismisses the notification everywhere and closes the Control Center/popup. Expanded popup opens on single click immediately. Clickable rows show hover highlight, pointer cursor and a fade-in open glyph (no tooltip) | CC7. **Status: accepted, implementation pending** |
