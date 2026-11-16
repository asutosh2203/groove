# Colour audit (D-45)

Every hardcoded colour in `contents/ui` (QML and JS, not the weather SVGs, which are content), as found at B2.
The rule (D-45): colour encodes attention, never decoration. About 130 literals across 40 files; most are neutral
graphite and left alone. This lists what is **not** monochrome. Nothing below was changed by B2 unless marked.

## Changed in B2
| Where | Was | Now |
|---|---|---|
| `activities/JobCompact.qml`, `JobExpanded.qml` | green `#42d77d`, tints `#e8f7ec` `#c7f9d4` `#101714` `#243a2b`, orange `#ff9f0a` `#ffd7a1` when paused | `Tokens.js` neutrals; paused is text plus `disabledOpacity` |
| `IslandGlyph.qml` job ring and arrow | `#42d77d` | `T.fill` |
| `main.qml` job `progressAccent` | `#42d77d` | `T.fill` |

## Non-monochrome, not decoration-free: need your decision
| Where | Colour | What it is | Suggestion |
|---|---|---|---|
| `IslandGlyph.qml:64` media bars | `#5ac8fa` blue | compact media glyph | neutral `T.fill` |
| `main.qml:381` media `progressAccent`, `ActivityProvider.qml:14`, `ActivityController.qml:75`, `ProgressBar.qml:9`, used by `shell/ActivityPage.qml:63` | `#5ac8fa` blue | default progress fill of the generic activity page | neutral token |
| `IslandGlyph.qml:76` notice glyph | `#ff9f0a` orange (+ `#050507` "!") | compact notice glyph | decide: urgency colour or neutral |
| `activities/NotificationCompact.qml:39,74,75,84` | `#ff9f0a` pulse, `#2a1c0c` fill, `#73480d` border, `#ffd7a1` text | unread badge | this is attention; keep, or move to one `unread` token |
| `logic/Notifications.js:55-59` `accent(kind)` | critical `#ff453a`, low `#8f9099`, **normal orange `#ff9f0a`** | icon-less notice accent | urgency, allowed; but Normal is orange here and green in the dot below |
| `logic/Notifications.js:68-72` `urgencyColor` | low `#6c6e78`, critical `#E66A65`, normal `#3ac255` | urgency dot (D-18) | allowed; the one sanctioned colour. Note Critical red differs from `T.critical` `#ff453a` |
| `ControlCenterEditor.qml:699,728,738` | `#211516`, `#693234`, `#ffb4ae` | red "invalid layout" state | attention, plausibly allowed; move to tokens |
| `IslandButton.qml:15`, `main.qml:655-656` | `#8e8eff` indigo | focus ring, edit-mode drag ghost border | `T.focusRing` is already neutral (`#8cffffff`); use it |
| `main.qml:655,674` | `#20212a`, `#f8f8fb` | drag ghost fill and icon, slightly blue | neutral tokens |

## Blue-tinted neutrals (near-monochrome, a slight blue/violet cast)
`KeyboardLayoutExpanded.qml` (`#14141c #353546 #242433 #48485e #9999a6 #aaaab5 #dadae8`), `shell/KeyboardVisual.qml`
(`#1b1b25 #3d3d50 #e2e2ed`), `NotificationVisual.qml`, `ArtworkVisual.qml`, `shell/MaskedArtwork.qml`,
`controlcenter/MaskedArtworkTile.qml` (`#101015 #262631`), `IslandButton.qml` (`#17171d #2d2d35 #484852 #34343c #1b1b21
#2a2a31`), `RoundShape`/`NotchShape` (`#121216 #060608 #16161b`), `PopupContent.qml` (`#050507 #202027`). Cast is about
3 to 8 levels of blue; the Control Center tokens are true greys. Suggest one pass moving these to tokens (keeping or
neutralising the cast is your call).

## Neutral literals that duplicate a token (safe to swap, no visual change)
`#ffffff` (18), `#9a9ca6` = `T.textCaption` (4), `#8d8f99` = `T.textSecondary` (4), `#25252b` = `T.track`/`T.border` (5),
`#34343c` = `T.borderStrong`, `#bfc2cc`/`#b4b6bf` (media ink and fill), `#e9e9ef`, `#e1e2e8`. Not done in B2 to keep
the diff on the job path and to avoid conflicts with the N1 branch (`PopupContent`, `Tokens.js`, `ControlCenterEditor`).
