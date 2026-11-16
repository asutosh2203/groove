# Widget architecture (draft)

Status: design notes, nothing here is built except `logic/Subscribers.js` and the WeatherService migration.
Everything is **decided** unless marked **proposed** (a draft for review). Decisions cite their entry (D-xx,
principles in `DECISIONS.md`). The plan lives in `ROADMAP.md`.

## Overview

```
                      ┌────────────────────── the deck (one expanded surface) ──────────────────────┐
 panel capsule ─click─▶  [Live] ─ [Preset 1] ─ [Preset 2] … [Preset 5] ─ [Control Center]              │
 (fixed ~180×40)      │    │            │                                        │                    │
                      │    │            └─ page = cells: small 2×1 · large 4×1   └─ tiles (own editor,│
                      │    │               each widget fills 1×1 / 2×1 / 4×1          merged into edit  │
                      │    └─ running media + jobs, stacked                           mode)             │
                      └─────────────────────────────────────────────────────────────────────────────────┘
                                      │ host creates a view when its page shows, destroys it on hide
                                      ▼
   widget view ──subscribes──▶ service (ref-counted, one per settings key per island) ──▶ D-Bus / HTTP / models
        ▲                          │ keeps last value while asleep; works only while subscribed (+30 s grace)
        └── host supplies: size · settings · tokens · services · visibility · host APIs · standard states
```

Notifications and the keyboard layout stay pop-ins over the deck, not pages (they pre-empt, D-38).

## The deck (decided)

- Order: [Live] → [Presets 1-5] → [Control Center, always last]. Live shows only when something runs; with no presets
  the deck is [Live] + [Control Center], close to today's behaviour. The page indicator hides when there is one page.
- Navigation is one horizontal axis. Indicator: pill = Live, dots = presets, gear = Control Center. Dots are clickable;
  horizontal touchpad swipe works too. No vertical paging (it conflicts with scrolling content).
- Entry: a capsule click opens the deck (Live if something runs, else the last-used page). The idle hot zones keep
  calendar and forecast (D-12); double-click opens the Control Center page; Esc or an outside click closes.
- Transitions: silhouette morph plus content cross-fade. The window is pre-sized for the largest page in the cycle before
  the deck shows, because resizing a visible dialog on Wayland shows a stretched frame (D-43).
- Fixed panel anchor, expansion in a separate dialog (principle 2); one shell, two appearances (principle 1).

## Presets and the grid (decided)

- Up to 5 presets. Each is a user-picked set of widgets in a template; no freeform editor (D-24). The user chooses which
  presets are in the cycle and their order.
- Horizontal in v1 (D-48): small = 2×1 cells, large = 4×1 (twice the width, same height), growing symmetrically from the
  notch. The grid is defined in cell spans, so taller pages (for example 2×2) can come later without changing widgets.
- A widget declares the spans it supports (1×1, 2×1, 4×1).

## Preset editor (decided)

One edit mode for the whole deck. The pencil on any page enters it and the island zooms about 104% on a soft spring.
Preset pages edit presets; the Control Center page edits tiles (the existing CC editor merges into this mode).

- Top: preset name (click to rename) and a Small/Large toggle. Large → Small is blocked with a hint when widgets do not
  fit; nothing is auto-removed.
- Grid: "−" removes a widget; "+ Add widget" opens the catalogue filtered to spans that fit; drag to reorder; clicking a
  widget opens its generated settings form in place (← back).
- Bottom: preset chips in cycle order. Drag to reorder, the eye toggles cycle membership, "+ New" (disabled at 5).
- Transactional: Done saves everything; Cancel or Esc discards. With unsaved changes an in-island "Discard your changes?"
  prompt appears ([Keep editing] / [Discard]); Esc on the prompt keeps editing. No prompt when nothing changed.
  Deleting a preset is staged until Done.

## Services and lifecycle (decided)

- Services are keyed by their settings; identical settings share one instance, within one island instance only, never
  globally, so two islands on two monitors never share state (D-37, no QML singletons).
- Ref-counted: a service works (polls, listens) only while subscribers > 0. After the last one leaves, a 30 s grace
  keeps it alive, which also covers retries; then it stops. Pure state in `logic/Subscribers.js` (Node-tested), timers in
  the QML service (principle 9).
- Cache-first rendering: a service keeps its last value while asleep, a view renders it at once, and the first subscriber
  refreshes only if it is stale (`WeatherCodes.isStale`). Preloading neighbour pages is deferred.
- Views are created when their page shows and destroyed when it hides. The idle face is an ordinary subscriber; the popup
  copy of it is not.
- The host renders the standard states: loading, ready, stale, error, needs setup.
- Migrated: WeatherService (the panel idle face subscribes while visible). Others follow with their widgets.

## Widget contract

Built-in widgets first; third-party extensions only after this contract is stable, and they must be GPL-compatible
(D-25).

**Decided**
- One view component per supported cell span (1×1, 2×1, 4×1), sharing sub-components as needed. A widget never sees the
  grid, only its own cell box.
- A widget may appear more than once in a preset, with its own settings per placement.
- No scrolling inside widgets (v1). Interaction is plain clicks and buttons only (v1).
- Side effects go only through host APIs (open URL, launch app, notify); a widget never runs commands or writes config.
- The settings UI is generated from the schema (P11); widgets ship no settings screens.
- Services, lifecycle and the standard states are as in the section above.

**Proposed (for review)**
- Manifest fields: `id`, localised `name` and `description`, `icon` (theme symbolic name with a fallback chain, D-26),
  `spans` (subset of 1×1, 2×1, 4×1), a `settings` schema, `version` (of the widget's settings, see Persistence), the
  `services` it subscribes to, and the permissions it needs (network, D-Bus names).
- Settings field types: bool, enum, string, number, location, app. Each has a label and a default; the host stores values
  per placement.
- Lifecycle hooks: `onShown` and `onHidden` (the view exists only between them), `onSettingsChanged`. Anything that keeps
  running is a service subscription, never a view timer.
- Host provides to a view: its span and pixel box, its settings values, design tokens (`Tokens.js`, D-47), injected
  services, a visibility flag, and the host APIs above.
- A widget reports its state (loading, ready, stale, error, needs setup) and the host draws the placeholder.

## Persistence (decided)

- Presets are stored per island instance in the plasmoid config as one versioned JSON blob (names, order, cycle
  membership, placements with span and settings).
- Format changes ship tested pure-JS migrations. Each widget's settings carry their own version, migrated the same way.
- A placement whose widget no longer exists keeps its data and shows a "Widget unavailable" slot; the preset is never
  dropped and nothing crashes.
- A fresh install has no presets: the deck is Live + Control Center. Starter presets are deferred.
- Presets save only on Done (see the editor).

## Open questions

- Manifest, settings field types, hooks and host API surface (the proposed items above).
- Permission model details, and how a widget declares the D-Bus names it may use.
- Context-aware presets (later).
