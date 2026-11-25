# Widget architecture

Status: the deck, the host, the registry, presets and the first widgets are built (D1, D2). The preset editor is D3.
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
  fallback chains (D-26). A click on an item goes to that page; there is no swipe and no scroll paging (the capsule scrub, D-62, is the one drag), so content
  (the jobs list) keeps its own vertical scroll. The capsule is hidden with one page, in Control Center edit mode and
  while a pop-in shows (it returns after). It is a satellite of the deck, not a second island: it has the island's surface
  but no glow, and it shares the deck's window, so principle 1 (one shell) still holds. Pages themselves pad all four
  sides equally and never grow for navigation.
- The capsule also scrubs (D-62): press and drag across it to move between pages (item boundaries at the midpoints between
  centres; the highlight follows the pointer, the page switches per crossing or after `scrubDwell`, and on release). Page
  content is deliberately not draggable.
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

## Preset editor (decided, D-56)

One edit mode for the whole deck, entered from the Control Center's pencil (no pencil on preset pages). The island zooms
about 104% on a soft spring; the capsule is hidden and Live is excluded. The window is pre-sized for it (D-43). The
Control Center tile editor is merged in as the gear chip.

- Top bar: a Small / Wide / Tall control for the current preset (a type the placements do not fit is blocked with a hint;
  nothing is auto-removed) and the Control Center editor's ✕ and ✓ for the whole session. In the settings form the left
  side is "‹ <widget name>". No preset names: presets are shown as silhouettes, the `name` stays optional in the format.
- Grid: the page at real size in a dashed outline. "−" removes a widget, a click opens its settings form in place, a drag
  reorders (reflow by the packing rule), a free cell reads "+ Add widget" and chooses where the catalogue adds. A
  placement the page cannot take is listed first in the sidebar as "Doesn't fit" so it can be fixed.
- Catalogue sidebar: icon, localised name and spans per widget; widgets that fit nowhere are greyed with "won't fit".
  Click adds to the chosen cell or the first free spot, a drag drops it on the grid.
- Settings form (generated from the manifest schema): the widget centred at real size on a full-width stage, the size row
  (plain text for a single-size widget), the fields in two columns, "Remove widget" bottom left. The island fits the form; a manifest may declare at most eight fields. Field types: note (a read-only line the widget computes from its other settings, `WidgetNotes.js`; no value, no default), bool (switch), enum (segmented up to four
  options, else dropdown; options may carry localised `labels`), string, number (always a stepper; optional localised `unit` shown in the value, e.g. "25 min", and `zeroLabel`, e.g. "None", shown instead of 0), location (Open-Meteo
  search) and timezone (Plasma's zone data, plain id fallback). `app` is reserved, not built.
- Bottom: one chip per preset with a silhouette of its layout. Hover shows an eye (cycle membership) and a "−" (delete,
  staged until Done); drag to reorder; the gear chip opens the tile editor; "+ New" adds a blank Small preset and is
  disabled at three ("3 of 3 presets").
- Transactional: Done saves everything (presets only through a blob that passes validation, never while `devPresets` is
  set); Cancel discards. With unsaved changes ✕, Esc and a click on the window's transparent area show the in-island
  "Discard your changes?" prompt ([Keep editing] / [Discard]); Esc on the prompt keeps editing. Closing the deck on focus
  loss keeps the draft in memory and the next open resumes it ("Unsaved changes restored"). Esc steps back one level:
  field, form to grid, grid to Cancel.

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

**Contract v1 (decided, D-54)**
- Manifest: one `manifest.json` per widget in `contents/ui/widgets/<id>/`. Fields: `contract` (1), `id`, `name` and
  `description` (objects keyed by locale, `en` required), `icon` (theme symbolic name or a fallback chain, D-26), `spans`
  (subset of 1x1, 2x1, 4x1) with a `defaultSpan`, `category` (Info, Media, System, Dev), `version` (of the widget's
  settings, see Persistence), `services` (what the host injects: `clock`, `weather`, `agents`, `timer`) and a `settings` schema.
- Views: one per supported span, named `View<span>.qml` (for example `View2x1.qml`) next to the manifest; shared
  sub-components are allowed. A view lays out from its injected pixel box only, never from hardcoded cell sizes (a 1x1 is
  154 wide on Small, 158 on Wide and 104 tall on Tall).
- Settings field types: bool, enum, string, number (with `min`, `max`, `step`), location, timezone, app. Each has a label
  and a default; the host stores values per placement. There is no colour picker (D-45).
- Enum option labels (added in D3, D-56): an enum field may carry `labels`, an object keyed by option id whose values are
  locale-keyed texts with `en` required, for example `"labels": { "highlow": { "en": "High / low" } }`. The settings form shows
  the label in the user's locale, then `en`, and an option without a label shows its id. The registry rejects a `labels`
  key that is not one of the field's options or has no `en` text. It is optional, so contract v1 manifests without it stay
  valid.
- The host injects (required properties): `span` and the pixel box (`boxWidth`, `boxHeight`), `settings` (resolved against
  the schema), `tokens`, the declared services only, the locale and time format, a reduced-motion flag, and a host API
  (open URL, launch app).
- The host subscribes to the declared services when the view is created and releases them when it is destroyed, so a
  view cannot forget to.
- A widget reports its `widgetState` (loading, ready, stale, error, needsSetup), `lastUpdated` and, optionally, a
  `clickAction`. The host draws the loading, error and needs-setup placeholders and injects `staleText` ("updated 2 h ago")
  while stale, which the view shows in place of its detail line so the three-line structure holds; it runs the click
  action through the host API before closing the deck (D-31 style).
- The registry validates manifests as pure data (`logic/WidgetRegistry.js`) without instantiating any QML; an invalid
  manifest is skipped with a log line. QML cannot list a directory or read a file, so `scripts/gen-widgets.cjs` mirrors
  all manifests into `widgets/Manifests.js` (never edit it; a Node test fails on drift).

**Cut from the early proposal**
- No lifecycle hooks (`onShown`, `onHidden`, `onSettingsChanged`): a view exists only while its page shows, it is created
  with `Component.onCompleted`, settings changes arrive through bindings and service subscriptions end with the view.
- No visibility flag, for the same reason.
- No permission model in v1: QML cannot enforce one. When third-party widgets arrive (D-25) enforcement must be real (a
  separate process or a restricted engine), never a manifest field alone.

## Catalogue (built-in widgets)

| id | Category | Spans | Services | Notes |
|---|---|---|---|---|
| `clock` | Info | 1x1 | clock | Time and date for a zone (D-55) |
| `world-clock` | Info | 2x1 | clock | Three zones (D-55) |
| `weather` | Info | 1x1, 2x1, 4x1 | weather | Left block, days, hours (D-55) |
| `pomodoro` | Info | 1x1, 2x1, 4x1 | timer | Focus and break timer, round dots, optional Do Not Disturb during focus (D-64) |
| `claude-code` | Dev | 1x1, 2x1 | agents | Plan usage or spend, attention, resting; the 2x1 lists live and recent sessions (D-60) |

`timer` is the host's handle on `TimerService`: one timer per placement, looked up by the placement's `pid` (the view's `pid`
property), in memory only. A placement's `pid` is a stable id assigned by the presets (format 2); reordering or editing keeps it
and a duplicate gets a fresh one.

`agents` is the host's handle on `AgentService` (the island's own instance, always on and event-driven, so it needs no
subscription). A view that acts on a part of itself, such as a row, emits `runAction(action)`; the host runs it like a
`clickAction` and closes the deck. The `agent` action raises a session's window and does nothing when none matches.

## Persistence (decided)

- Presets are stored per island instance in the plasmoid config as one versioned JSON blob (names, order, cycle
  membership, placements with pid, span and settings).
- Format changes ship tested pure-JS migrations. Each widget's settings carry their own version, migrated the same way.
- A placement whose widget no longer exists keeps its data and shows a "Widget unavailable" slot; the preset is never
  dropped and nothing crashes.
- A fresh install has no presets: the deck is Live + Control Center. Starter presets are deferred.
- Presets save only on Done (see the editor).

## Open questions

- How third-party widgets are isolated (D-25), since v1 has no permission model.
- Context-aware presets (later).
