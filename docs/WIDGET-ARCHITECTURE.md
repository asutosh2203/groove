# Widget architecture (draft)

Status: design notes, nothing here is built except `logic/Subscribers.js` and the WeatherService migration.
Everything is **decided** unless marked **proposed** (a draft for review). Decisions cite their entry (D-xx,
principles in `DECISIONS.md`). The plan lives in `ROADMAP.md`.

## Overview

```
                      ┌──────────────────── the deck (one expanded surface) ─────────────────────┐
 island ──click──▶    │  [Live] ─ [Preset 1] ─ [Preset 2] ─ [Preset 3] ─ [Control Center]        │
 (fixed ~180×40)      │    │           │                                 │                       │
                      │    │           └─ page = cells: Small 2×1 ·      └─ tiles (own editor,   │
                      │    │              Wide 4×1 · Tall 2×2;               merged into edit    │
                      │    │              widgets 1×1 / 2×1 / 4×1           mode)                │
                      │    └─ running media + jobs, as cards                                     │
                      └──────────────────────────────────────────────────────────────────────────┘
                        ▲ the page-control capsule floats just below the island: Live · dots · Control Center
                                      │ host creates a view when its page shows, destroys it on hide
                                      ▼
   widget view ──subscribes──▶ service (ref-counted, one per settings key per island) ──▶ D-Bus / HTTP / models
        ▲                          │ keeps last value while asleep; works only while subscribed (+30 s grace)
        └── host supplies: size · settings · tokens · services · visibility · host APIs · standard states
```

Notifications and the keyboard layout stay pop-ins over the deck, not pages (they pre-empt, D-38).

## The deck (decided)

- Order: [Live] → [Presets, at most 3] → [Control Center, always last]. Live shows only when something runs; with no
  presets the deck is [Live] + [Control Center], close to today's behaviour. The worst case is five pages.
- Navigation is by a page-control capsule: a small pill floating just below the island (about 7 px gap), centred on it
  and following its bottom edge as the island morphs. Left to right in deck order it holds a glyph for Live, one dot per
  preset (at most 3) and a glyph for the Control Center. The current page is full white (its dot stretches to a short pill),
  the others a muted neutral that brightens on hover (D-45, lightness only). Glyphs are theme symbolic icons with
  fallback chains (D-26). A click on an item goes to that page; there is no swipe and no scroll paging in D1, so content
  (the jobs list) keeps its own vertical scroll. The capsule is hidden with one page, in Control Center edit mode and
  while a pop-in shows (it returns after). It is a satellite of the deck, not a second island: it has the island's surface
  but no glow, and it shares the deck's window, so principle 1 (one shell) still holds. Pages themselves pad all four
  sides equally and never grow for navigation.
- If three presets feel restrictive, fallback B: a three-section capsule (Live / Presets / Control Center) whose middle item
  shows the current preset and cycles the presets when clicked again. Not built.
- Entry: a capsule click opens the deck (Live if something runs, else the last-used page). The idle hot zones keep
  calendar and forecast (D-12); double-click opens the Control Center page; Esc or an outside click closes.
- Transitions are horizontal: moving right in the capsule slides content left and vice versa, with the silhouette morph
  and a cross-fade (cross-fade only with reduced motion; the capsule then appears without its settle). Opening morphs the
  island first and then fades the capsule in; closing fades it out first. Moves between Wide and Tall pages morph both
  axes. The window (including the notch's ears and the capsule's gap and height) is
  pre-sized to the union of the largest width and the largest height in the cycle before the deck shows, because resizing
  a visible dialog on Wayland shows a stretched frame (D-43). An outside click still closes the deck.
- The Control Center page keeps its current tall layout; the morph into it is accepted for v1.
- Fixed panel anchor, expansion in a separate dialog (principle 2); one shell, two appearances (principle 1).

## Live page (decided, D-52 and D-53)

- One activity is a Small page; two or more are a Tall page (two fixed 2x1 slots), and the page morphs between them.
- Media is always the top card (the bare expanded media view). Jobs are always tiles.
- Jobs are full tiles, one per slot, when they fit (one job alone; media + 1 job; 2 jobs without media). Otherwise they are
  a list: in the bottom slot under media (media + 2 or more jobs) or over the whole page (3 or more jobs). The list has a
  summary header (combined percent, longest time left, kind noun or "N transfers") and scrolls.
- In list mode the page height fits its content (media card, header, rows), between the Small and Tall heights, and the list
  scrolls only past the Tall cap. The media card keeps its Small-page height and a hairline separates it from the header.
- The capsule's Live glyph follows the page: a music note (a film glyph for video) when media shows, else the one kind all
  jobs share (download, upload, trash, copy, move), else a transfer glyph (D-53). The same chain table (`LiveGlyphs.js`)
  gives the list header and each row their glyph, so they always agree.
- A full job tile with a usable destination opens it in the file manager; a compact list row opens in place into a full
  tile (accordion, one at a time). The media card's artwork and title raise the player: an exact id match, then a looser
  match only when exactly one task matches, else MPRIS `Raise()` (D-53).
- Newest job first. There is no paging and no "+N" chip.
- Same-kind merging and per-job pause and cancel are not built.
- Page sizes follow the grid (D-48); the window is pre-sized for the cycle's largest page (D-43).

## Presets and the grid (decided)

- Up to 3 presets (so the worst case is five capsule items). Each is a user-picked set of widgets in a template; no
  freeform editor (D-24). The user chooses which presets are in the cycle and their order.
- Three page types, measured in cell units (D-48): **Small** 2×1, **Wide** 4×1 (twice as wide), **Tall** 2×2 (twice as
  tall). Horizontal pages grow symmetrically from the notch.
- Widget spans: **Small** 1×1, **Medium** 2×1, **Wide** 4×1 (Wide page only). The Tall page reuses the 1×1 and 2×1 views,
  so no extra widget views exist for it. Large 2×2 square widgets for the Tall page come later.

## Preset editor (decided)

One edit mode for the whole deck. The pencil on any page enters it and the island zooms about 104% on a soft spring.
Preset pages edit presets; the Control Center page edits tiles (the existing CC editor merges into this mode).

- Top: preset name (click to rename) and a page-type toggle (Small / Wide / Tall). Switching to a page type where
  widgets do not fit is blocked with a hint; nothing is auto-removed.
- Grid: "−" removes a widget; "+ Add widget" opens the catalogue filtered to spans that fit; drag to reorder; clicking a
  widget opens its generated settings form in place (← back).
- Bottom: preset chips in cycle order. Drag to reorder, the eye toggles cycle membership, "+ New" (disabled at 3).
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
- One view component per supported cell span (1×1, 2×1, 4×1; the Tall page adds none), sharing sub-components as needed. A widget never sees the
  grid, only its own cell box.
- A widget may appear more than once in a preset, with its own settings per placement.
- No scrolling inside widgets (v1). Interaction is plain clicks and buttons only (v1).
- Side effects go only through host APIs (open URL, launch app, notify); a widget never runs commands or writes config.
- The settings UI is generated from the schema (P11); widgets ship no settings screens.
- Services, lifecycle and the standard states are as in the section above.

**Proposed (for review)**
- Manifest fields: `contract: 1` (the contract version), `id`, localised `name` and `description`, `icon` (theme
  symbolic name with a fallback chain, D-26), `spans` (subset of 1×1, 2×1, 4×1) with a `defaultSpan`, an optional
  `category` (Info, Media, System or Dev), a `settings` schema, `version` (of the widget's settings, see Persistence), the
  `services` it subscribes to, and the permissions it needs (network, D-Bus names).
- Settings field types: bool, enum, string, number (with `min`, `max`, `step`), location, timezone, app. Each has a label
  and a default; the host stores values per placement. There is no colour picker (D-45).
- Lifecycle hooks: `onShown` and `onHidden` (the view exists only between them), `onSettingsChanged`. Anything that keeps
  running is a service subscription, never a view timer.
- Host provides to a view: its span and pixel box, its settings values, design tokens (`Tokens.js`, D-47), injected
  services, a visibility flag, the locale and time format, a reduced-motion flag, and the host APIs above.
- A widget reports its state (loading, ready, stale, error, needs setup) and the host draws the placeholder, including the
  stale age ("updated 2 h ago").

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
