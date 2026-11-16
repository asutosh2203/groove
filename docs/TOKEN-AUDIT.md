# Token audit

Hardcoded layout and motion values outside `controlcenter/Tokens.js`, as found on `fix/b2-job-style-r1` (B2 included).
Nothing was changed. Companion to `COLOUR-AUDIT.md`.

**Method.** A script scans every `.qml` and `.js` under `contents/ui` (not `Tokens.js`, not the weather SVGs) for a
property set to a bare numeric literal: `radius`, `font.pixelSize`, `spacing`, padding, margins, `opacity`, `duration`,
`interval`, `easing.type`, and `width`/`height`/`glyphSize` inside icon items. **It misses expressions** (`width * 0.22`,
`Math.max(3, ...)`, anything computed), so real counts are higher; treat the totals as a floor. Timer intervals are in
the motion table because they are hardcoded durations, but most are polling cadences, not animation. "Nearest token" is the
closest value in `Tokens.js`; where there is none, it says so.

**Tokens that exist today:** radii `radiusCard 20`, `radiusInner 14`; icon `iconHeader 18`; `disabledOpacity 0.45`;
spacing `gap 8`, `padding 12`, `paddingCompact 8`; fonts `14 / 13 / 11 / 10`; motion `motionFast 120`, `motionSlider 90`.
There is **no** token for small radii, icon sizes other than 18, easing, or durations beyond those two.

## Totals (literals found / files)
| Kind | Literals | Files |
|---|---|---|
| Radius | 16 | 13 |
| Font size | 27 | 10 |
| Icon size | 25 | 10 |
| Spacing/padding | 57 | 20 |
| Margins | 50 | 17 |
| Opacity | 7 | 5 |
| Motion (duration/easing/interval) | 47 | 23 |

## What stands out (for triage)
1. **Easing has no token.** `Easing.OutCubic` is hardcoded 12 times (Control Center tiles, `JobExpanded`); `PopupContent` uses a
   one-off `BezierSpline`. One `easingStandard` token would cover all 12.
2. **Control Center durations cluster at 105 ms (x8)** plus 100 and 110, next to `motionFast 120`. Looks like the same
   intent, drifted; candidates to fold into `motionFast`. Island-level animations (`main.qml` 18/90/210/360, `IslandCompact` 180,
   `PopupContent` 340, `NotificationCompact` 520) are a separate, unnamed scale.
3. **Font 9 px is used 9 times** (job views, notice views) and sits below the smallest token (`fontCaption 10`). 12 (x4), 15 and 16 (x3) have no token.
4. **Off-grid spacing:** 7 (x9 in spacing, x5 in margins) and 5 (x8) against a token grid of 8 and 12. 6 and 10 also recur.
5. **Icon sizes are a free-for-all:** 17 (x4) and 23 (x2) repeat in `MusicExpanded` and `ActivitySummaryTile`
   (the same transport-button set, probably meant to be one size), plus 14, 15, 18, 20, 22, 24, 26, 32, 34, 36.
   Only `ControlCenterEditor` uses the 18 that has a token. `JobExpanded` uses 24 (B2).
6. **Radii:** only 20 and 14 have tokens; 12, 16 (x2), 17, 10 and 9 are near-misses of 14, and the many 2-5 px radii are
   bar/pill ends that want one `radiusSmall`. `JobExpanded` tile radius 12 vs `ActivityPage` 16 vs `KeyboardLayoutExpanded` 16 for what should be the same tile.
7. **Opacity** is nearly clean: the only literals that are not 0 or 1 are 0.85, 0.7, 0.62 and 0.16, none equal to `disabledOpacity 0.45`.
8. **Not literal, so not listed:** values computed from other values, and `T.*` uses, which are the intended state.


## Radii

Distinct values (count): `4` x3, `16` x2, `2` x2, `17` x1, `12` x1, `10` x1, `1` x1, `2.5` x1, `9` x1, `5` x1, `3` x1, `8` x1

| File | Line : value -> nearest token |
|---|---|
| `activities/JobExpanded.qml` | 59: `12` -> radiusInner/Card=14 (Δ-2) |
| `activities/KeyboardLayoutExpanded.qml` | 19: `16` -> radiusInner/Card=14 (Δ+2); 68: `10` -> radiusInner/Card=14 (Δ-4) |
| `activities/MuteButton.qml` | 54: `1` -> radiusInner/Card=14 (Δ-13) |
| `activities/NotificationExpanded.qml` | 176: `2.5` -> radiusInner/Card=14 (Δ-11.5) |
| `controlcenter/ControlCenterModuleCard.qml` | 122: `9` -> radiusInner/Card=14 (Δ-5) |
| `controlcenter/IslandBars.qml` | 31: `2` -> radiusInner/Card=14 (Δ-12) |
| `controlcenter/KdeConnectTile.qml` | 154: `4` -> radiusInner/Card=14 (Δ-10); 298: `4` -> radiusInner/Card=14 (Δ-10) |
| `controlcenter/NetworkListTile.qml` | 139: `4` -> radiusInner/Card=14 (Δ-10) |
| `controlcenter/NotificationRowSlot.qml` | 76: `5` -> radiusInner/Card=14 (Δ-9) |
| `controlcenter/NotificationsTile.qml` | 308: `3` -> radiusInner/Card=14 (Δ-11); 380: `8` -> radiusInner/Card=14 (Δ-6) |
| `controlcenter/SimpleModuleTile.qml` | 130: `2` -> radiusInner/Card=14 (Δ-12) |
| `main.qml` | 687: `17` -> radiusInner/Card=14 (Δ+3) |
| `shell/ActivityPage.qml` | 18: `16` -> radiusInner/Card=14 (Δ+2) |

## Font sizes (px)

Distinct values (count): `9` x9, `10` x6, `12` x4, `16` x3, `11` x2, `14` x1, `13` x1, `15` x1

| File | Line : value -> nearest token |
|---|---|
| `activities/JobCompact.qml` | 28: `9` -> font*=10 (Δ-1); 38: `9` -> font*=10 (Δ-1) |
| `activities/JobExpanded.qml` | 89: `12` -> font*=11 (Δ+1); 114: `9` -> font*=10 (Δ-1); 140: `9` -> font*=10 (Δ-1); 149: `9` -> font*=10 (Δ-1) |
| `activities/KeyboardLayoutExpanded.qml` | 40: `9` -> font*=10 (Δ-1); 48: `16` -> font*=14 (Δ+2); 59: `10` -> font*=10; 79: `11` -> font*=11 |
| `activities/MusicCompact.qml` | 26: `9` -> font*=10 (Δ-1) |
| `activities/MusicExpanded.qml` | 57: `14` -> font*=14; 67: `11` -> font*=11; 107: `10` -> font*=10; 156: `10` -> font*=10 |
| `activities/NotificationCompact.qml` | 22: `9` -> font*=10 (Δ-1); 85: `9` -> font*=10 (Δ-1) |
| `activities/NotificationExpanded.qml` | 57: `16` -> font*=14 (Δ+2); 64: `12` -> font*=11 (Δ+1); 158: `10` -> font*=10 |
| `shell/ActivityPage.qml` | 41: `13` -> font*=13; 51: `10` -> font*=10 |
| `shell/PopupContent.qml` | 254: `10` -> font*=10; 275: `12` -> font*=11 (Δ+1); 293: `12` -> font*=11 (Δ+1) |
| `weather/IdleContent.qml` | 121: `16` -> font*=14 (Δ+2); 159: `15` -> font*=14 (Δ+1) |

## Icon / glyph sizes

Distinct values (count): `17` x4, `32` x3, `18` x2, `24` x2, `23` x2, `15` x2, `34` x2, `22` x2, `14` x2, `26` x2, `36` x1, `20` x1

| File | Line : value -> nearest token |
|---|---|
| `ControlCenterEditor.qml` | 800: `18` -> iconHeader=18; 801: `18` -> iconHeader=18 |
| `activities/JobExpanded.qml` | 66: `24` -> iconHeader=18 (Δ+6); 67: `24` -> iconHeader=18 (Δ+6) |
| `activities/KeyboardLayoutExpanded.qml` | 26: `32` -> iconHeader=18 (Δ+14); 27: `32` -> iconHeader=18 (Δ+14) |
| `activities/MusicExpanded.qml` | 119: `17` -> iconHeader=18 (Δ-1); 130: `23` -> iconHeader=18 (Δ+5); 141: `17` -> iconHeader=18 (Δ-1) |
| `controlcenter/ActivitySummaryTile.qml` | 146: `17` -> iconHeader=18 (Δ-1); 156: `23` -> iconHeader=18 (Δ+5); 167: `17` -> iconHeader=18 (Δ-1); 235: `36` -> iconHeader=18 (Δ+18); 253: `15` -> iconHeader=18 (Δ-3); 265: `20` -> iconHeader=18 (Δ+2); 277: `15` -> iconHeader=18 (Δ-3) |
| `controlcenter/KdeConnectTile.qml` | 235: `34` -> iconHeader=18 (Δ+16); 236: `34` -> iconHeader=18 (Δ+16) |
| `controlcenter/UserPowerTile.qml` | 59: `22` -> iconHeader=18 (Δ+4); 60: `22` -> iconHeader=18 (Δ+4) |
| `shell/ActivityPage.qml` | 25: `32` -> iconHeader=18 (Δ+14) |
| `shell/PopupContent.qml` | 328: `14` -> iconHeader=18 (Δ-4); 329: `14` -> iconHeader=18 (Δ-4) |
| `weather/IdleContent.qml` | 165: `26` -> iconHeader=18 (Δ+8); 166: `26` -> iconHeader=18 (Δ+8) |

## Spacing and padding

Distinct values (count): `8` x10, `7` x9, `5` x8, `6` x6, `2` x5, `0` x5, `4` x3, `12` x3, `-1` x3, `10` x2, `1` x2, `3` x1

| File | Line : value -> nearest token |
|---|---|
| `ControlCenterEditor.qml` | 469: `8` -> gap/padding=8; 680: `8` -> gap/padding=8; 710: `6` -> gap/padding=8 (Δ-2); 797: `7` -> gap/padding=8 (Δ-1) |
| `activities/AudioBars.qml` | 22: `2` -> gap/padding=8 (Δ-6) |
| `activities/JobCompact.qml` | 18: `2` -> gap/padding=8 (Δ-6); 22: `4` -> gap/padding=8 (Δ-4) |
| `activities/JobExpanded.qml` | 53: `10` -> gap/padding=8 (Δ+2); 79: `4` -> gap/padding=8 (Δ-4); 83: `8` -> gap/padding=8 |
| `activities/KeyboardLayoutExpanded.qml` | 13: `12` -> gap/padding=12; 34: `3` -> gap/padding=8 (Δ-5) |
| `activities/MusicCompact.qml` | 15: `5` -> gap/padding=8 (Δ-3); 20: `2` -> gap/padding=8 (Δ-6) |
| `activities/MusicExpanded.qml` | 23: `12` -> gap/padding=12; 43: `0` -> gap/padding=8 (Δ-8); 47: `8` -> gap/padding=8; 51: `1` -> gap/padding=8 (Δ-7); 101: `0` -> gap/padding=8 (Δ-8) |
| `activities/NotificationCompact.qml` | 16: `5` -> gap/padding=8 (Δ-3) |
| `activities/NotificationExpanded.qml` | 71: `12` -> gap/padding=12; 152: `6` -> gap/padding=8 (Δ-2) |
| `controlcenter/ActivitySummaryTile.qml` | 64: `0` -> gap/padding=8 (Δ-8); 68: `8` -> gap/padding=8; 71: `1` -> gap/padding=8 (Δ-7); 132: `0` -> gap/padding=8 (Δ-8); 188: `8` -> gap/padding=8; 191: `8` -> gap/padding=8; 292: `0` -> gap/padding=8 (Δ-8); 322: `8` -> gap/padding=8; 374: `2` -> gap/padding=8 (Δ-6) |
| `controlcenter/ControlSliderTile.qml` | 147: `6` -> gap/padding=8 (Δ-2) |
| `controlcenter/IslandBars.qml` | 22: `4` -> gap/padding=8 (Δ-4) |
| `controlcenter/KdeConnectTile.qml` | 61: `7` -> gap/padding=8 (Δ-1); 65: `7` -> gap/padding=8 (Δ-1); 75: `-1` -> gap/padding=8 (Δ-9); 149: `7` -> gap/padding=8 (Δ-1); 161: `-1` -> gap/padding=8 (Δ-9); 188: `5` -> gap/padding=8 (Δ-3); 226: `2` -> gap/padding=8 (Δ-6) |
| `controlcenter/NetworkListTile.qml` | 45: `5` -> gap/padding=8 (Δ-3); 49: `7` -> gap/padding=8 (Δ-1); 134: `6` -> gap/padding=8 (Δ-2) |
| `controlcenter/NotificationRowSlot.qml` | 46: `8` -> gap/padding=8 |
| `controlcenter/NotificationsTile.qml` | 75: `7` -> gap/padding=8 (Δ-1); 79: `7` -> gap/padding=8 (Δ-1); 91: `-1` -> gap/padding=8 (Δ-9); 188: `7` -> gap/padding=8 (Δ-1); 241: `8` -> gap/padding=8; 266: `6` -> gap/padding=8 (Δ-2); 291: `5` -> gap/padding=8 (Δ-3) |
| `controlcenter/UserPowerTile.qml` | 136: `7` -> gap/padding=8 (Δ-1) |
| `shell/ActivityPage.qml` | 13: `10` -> gap/padding=8 (Δ+2); 35: `5` -> gap/padding=8 (Δ-3); 70: `6` -> gap/padding=8 (Δ-2) |
| `shell/IslandCompact.qml` | 82: `5` -> gap/padding=8 (Δ-3) |
| `shell/PopupContent.qml` | 197: `5` -> gap/padding=8 (Δ-3) |

## Margins

Distinct values (count): `8` x9, `4` x8, `10` x6, `7` x5, `2` x4, `6` x4, `1` x3, `9` x2, `3` x2, `5` x1, `-4` x1, `-2` x1, `-3` x1, `-5` x1, `17` x1, `14` x1

| File | Line : value -> nearest token |
|---|---|
| `ControlCenterEditor.qml` | 588: `8` -> gap/padding=8; 664: `8` -> gap/padding=8; 679: `10` -> gap/padding=8 (Δ+2); 760: `5` -> gap/padding=8 (Δ-3); 795: `9` -> gap/padding=8 (Δ+1); 796: `9` -> gap/padding=8 (Δ+1) |
| `activities/JobCompact.qml` | 16: `4` -> gap/padding=8 (Δ-4); 17: `2` -> gap/padding=8 (Δ-6) |
| `activities/JobExpanded.qml` | 44: `-4` -> gap/padding=8 (Δ-12); 122: `2` -> gap/padding=8 (Δ-6) |
| `activities/MusicCompact.qml` | 13: `4` -> gap/padding=8 (Δ-4); 14: `1` -> gap/padding=8 (Δ-7) |
| `activities/MusicExpanded.qml` | 22: `-2` -> gap/padding=8 (Δ-10); 100: `4` -> gap/padding=8 (Δ-4); 116: `8` -> gap/padding=8; 138: `8` -> gap/padding=8 |
| `activities/NotificationCompact.qml` | 14: `4` -> gap/padding=8 (Δ-4); 15: `2` -> gap/padding=8 (Δ-6) |
| `controlcenter/ActivitySummaryTile.qml` | 95: `3` -> gap/padding=8 (Δ-5); 131: `4` -> gap/padding=8 (Δ-4); 143: `8` -> gap/padding=8; 164: `8` -> gap/padding=8; 306: `1` -> gap/padding=8 (Δ-7); 370: `8` -> gap/padding=8 |
| `controlcenter/ControlCenterModuleCard.qml` | 93: `2` -> gap/padding=8 (Δ-6); 121: `7` -> gap/padding=8 (Δ-1) |
| `controlcenter/ControlSliderTile.qml` | 105: `10` -> gap/padding=8 (Δ+2); 146: `8` -> gap/padding=8; 185: `10` -> gap/padding=8 (Δ+2) |
| `controlcenter/KdeConnectTile.qml` | 60: `10` -> gap/padding=8 (Δ+2); 148: `7` -> gap/padding=8 (Δ-1); 237: `6` -> gap/padding=8 (Δ-2); 295: `7` -> gap/padding=8 (Δ-1) |
| `controlcenter/NetworkListTile.qml` | 44: `10` -> gap/padding=8 (Δ+2) |
| `controlcenter/NotificationRowSlot.qml` | 75: `-3` -> gap/padding=8 (Δ-11); 95: `-5` -> gap/padding=8 (Δ-13) |
| `controlcenter/NotificationsTile.qml` | 73: `10` -> gap/padding=8 (Δ+2); 74: `17` -> gap/padding=12 (Δ+5); 154: `6` -> gap/padding=8 (Δ-2); 240: `7` -> gap/padding=8 (Δ-1); 377: `7` -> gap/padding=8 (Δ-1) |
| `controlcenter/SimpleModuleTile.qml` | 161: `8` -> gap/padding=8 |
| `shell/IslandCompact.qml` | 80: `4` -> gap/padding=8 (Δ-4) |
| `shell/PopupContent.qml` | 195: `4` -> gap/padding=8 (Δ-4); 250: `1` -> gap/padding=8 (Δ-7); 271: `14` -> gap/padding=12 (Δ+2); 272: `6` -> gap/padding=8 (Δ-2); 313: `4` -> gap/padding=8 (Δ-4) |
| `weather/IdleContent.qml` | 154: `6` -> gap/padding=8 (Δ-2); 169: `3` -> gap/padding=8 (Δ-5) |

## Opacity

Distinct values (count): `1` x2, `0.85` x1, `0.62` x1, `0.7` x1, `0.16` x1, `0` x1

| File | Line : value -> nearest token |
|---|---|
| `ControlCenterEditor.qml` | 765: `0.85` -> disabledOpacity=0.45 (Δ+0.40); 774: `0.62` -> disabledOpacity=0.45 (Δ+0.17) |
| `activities/NotificationCompact.qml` | 40: `0.16` -> disabledOpacity=0.45 (Δ-0.29) |
| `configGeneral.qml` | 134: `0.7` -> disabledOpacity=0.45 (Δ+0.25) |
| `shell/PopupContent.qml` | 74: `1` -> (0/1: visibility, ignore); 85: `0` -> (0/1: visibility, ignore) |
| `weather/IdleContent.qml` | 167: `1` -> (0/1: visibility, ignore) |

## Animation durations, easing, timer intervals

Distinct values (count): `Easing.OutCubic` x12, `105` x8, `900` x3, `120` x2, `1000` x2, `520` x2, `30000` x2, `60000` x2, `110` x1, `360` x1, `18` x1, `210` x1, `90` x1, `100` x1, `150` x1, `700` x1, `2500` x1, `8000` x1, `180` x1, `340` x1, `Easing.BezierSpline` x1, `10` x1

| File | Line : value -> nearest token |
|---|---|
| `ControlCenterEditor.qml` | 674: `120` -> motionFast/Slider=120; 739: `105` -> motionFast/Slider=120 (Δ-15); 743: `105` -> motionFast/Slider=120 (Δ-15); 747: `105` -> motionFast/Slider=120 (Δ-15); 751: `105` -> motionFast/Slider=120 (Δ-15); 755: `110` -> motionFast/Slider=120 (Δ-10) |
| `PausableTimer.qml` | 10: `1000` -> motionFast/Slider=120 (Δ+880) |
| `activities/JobExpanded.qml` | 37: `Easing.OutCubic` -> no easing token |
| `activities/NotificationCompact.qml` | 48: `520` -> motionFast/Slider=120 (Δ+400); 49: `520` -> motionFast/Slider=120 (Δ+400) |
| `activities/NotificationExpanded.qml` | 43: `30000` -> motionFast/Slider=120 (Δ+29880) |
| `controlcenter/ControlCenterModuleCard.qml` | 33: `120` -> motionFast/Slider=120; 34: `100` -> motionFast/Slider=90 (Δ+10); 35: `105` -> motionFast/Slider=120 (Δ-15); 36: `105` -> motionFast/Slider=120 (Δ-15); 37: `105` -> motionFast/Slider=120 (Δ-15); 38: `105` -> motionFast/Slider=120 (Δ-15) |
| `controlcenter/ControlSliderTile.qml` | 81: `Easing.OutCubic` -> no easing token; 82: `Easing.OutCubic` -> no easing token |
| `controlcenter/KdeConnectTile.qml` | 54: `Easing.OutCubic` -> no easing token |
| `controlcenter/NetworkListTile.qml` | 38: `Easing.OutCubic` -> no easing token |
| `controlcenter/NotificationRowSlot.qml` | 40: `Easing.OutCubic` -> no easing token; 49: `Easing.OutCubic` -> no easing token; 87: `Easing.OutCubic` -> no easing token |
| `controlcenter/NotificationsTile.qml` | 49: `60000` -> motionFast/Slider=120 (Δ+59880); 228: `Easing.OutCubic` -> no easing token |
| `controlcenter/SimpleModuleTile.qml` | 62: `Easing.OutCubic` -> no easing token; 79: `Easing.OutCubic` -> no easing token; 141: `Easing.OutCubic` -> no easing token |
| `main.qml` | 572: `360` -> motionFast/Slider=120 (Δ+240); 588: `18` -> motionFast/Slider=90 (Δ-72); 609: `210` -> motionFast/Slider=120 (Δ+90); 701: `90` -> motionFast/Slider=90 |
| `services/AppLauncher.qml` | 196: `150` -> motionFast/Slider=120 (Δ+30) |
| `services/ConnectivityService.qml` | 122: `900` -> motionFast/Slider=120 (Δ+780); 130: `900` -> motionFast/Slider=120 (Δ+780); 138: `30000` -> motionFast/Slider=120 (Δ+29880) |
| `services/MediaService.qml` | 162: `1000` -> motionFast/Slider=120 (Δ+880) |
| `services/NotificationService.qml` | 352: `700` -> motionFast/Slider=120 (Δ+580) |
| `services/PanelController.qml` | 139: `2500` -> motionFast/Slider=120 (Δ+2380); 147: `8000` -> motionFast/Slider=120 (Δ+7880) |
| `services/SystemControls.qml` | 252: `900` -> motionFast/Slider=120 (Δ+780) |
| `shell/IslandCompact.qml` | 72: `180` -> motionFast/Slider=120 (Δ+60) |
| `shell/PopupContent.qml` | 398: `340` -> motionFast/Slider=120 (Δ+220); 399: `Easing.BezierSpline` -> no easing token |
| `weather/IdleContent.qml` | 82: `60000` -> motionFast/Slider=120 (Δ+59880) |
| `weather/WeatherService.qml` | 138: `10` -> motionFast/Slider=90 (Δ-80) |

## Flagged, not fixed: Wi-Fi tile gap (from the contact sheet, B3)
In the Control Center the Wi-Fi tile shows a large empty gap between its header row ("Wi-Fi", signal %) and the network name,
which sits at the bottom of the tile. It is most visible in the Notch frames, where the tile has no IP/"Wireless" line to fill
the space (`review/notch/11-control-center.png`); in the Pill frames the extra lines hide it
(`review/b3/pill/music-3-control-center.png`). The tile is `SimpleModuleTile` in `controlcenter/ControlCenterModuleCard.qml`
(`wifiModule`, `detailed` at 142 x 88 or larger). Cause not isolated: the header and the text stack are separate layouts, and
the stack is bottom-aligned. No token is involved (nothing here is a spacing literal); it is a layout decision.

## After T1
The top findings were fixed in T1; the literals the ratchet counts went from 232 to 170 (`scripts/check-tokens.cjs`, baseline
`.github/token-baseline.txt`). The scan in this document counted a line once; the ratchet counts every literal on a line, so its
motion figure is higher than the table above (60 before, 27 after) and `Easing.OutCubic` was really 23 sites, not 12.

| Kind | Before | After | What changed |
|---|---|---|---|
| Radius | 16 | 5 | Activity tiles use `radiusInner` (job 12, keyboard and activity page 16 became 14); bar, dot and pill ends use `radiusSmall` (4) |
| Font size | 27 | 18 | 9 px text raised to `fontCaption` (10), 8 sites |
| Icon size | 23 | 14 | Transport buttons: `iconTransport` 16 and `iconTransportPrimary` 22 (were 17/23 and 15/20) |
| Motion | 60 | 27 | `easingStandard` replaces `Easing.OutCubic` at 22 sites; the 100/105/110 ms Control Center durations and the card's 120 now use `motionFast` |
| Spacing, margins, opacity | 106 | 106 | untouched (not in T1) |

Left alone on purpose: `NetworkListTile.qml` and the Wi-Fi and Bluetooth tiles (C8), the 7 px and 5 px spacing, the 17/23-style
sizes outside the transport buttons, the long timers and polling intervals, and `ReplyShelf.qml`'s spring easing.
