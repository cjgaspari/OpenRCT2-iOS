# OpenRCT2 Touch controls

This document records iPad-specific input behavior on the `ipad` branch. The
port keeps OpenRCT2's existing mouse and keyboard paths intact and translates
touch gestures into those established actions wherever practical.

## Current mappings

| Input | Action | Design reason |
| --- | --- | --- |
| One-finger tap on UI | Primary click | Preserves ordinary OpenRCT2 button and window behavior. |
| One-finger move with a placement tool | Move the construction preview without placing it | A finger needs pointer-like hover before committing a ride, scenery item, entrance, or exit. |
| Double tap within 390 ms during placement | Confirm placement | Deliberate confirmation prevents an initial positioning touch from placing accidentally. |
| One-finger hold for 350 ms, then drag | Paint with footpath, land, water, or clear-scenery tools | Reuses each tool's existing left-button drag callback for continuous work. |
| One-finger long press outside those paint tools | Secondary click | Provides the normal contextual/right-click action without affecting one-finger placement movement. |
| Two-finger drag | Inverted, half-speed viewport pan | Matches direct-manipulation expectations while keeping movement precise. The first finger may land before the second without causing one-finger panning. |
| Two-finger pinch | Zoom | A deliberate span change must dominate centroid movement, preventing ordinary pans from becoming zooms. |
| Two-finger twist during supported placement | Rotate scenery, ride construction, or track-design placement | A 15-degree turn starts rotation. Pan waits for stronger translation while a rotatable tool is active, so twisting does not move the map first. |
| Two-finger tap while a removable construction tool is active | Secondary click/remove | Mirrors a trackpad secondary click without conflicting with primary placement. |
| Two-finger hold for 350 ms over a footpath, then drag | Remove footpaths continuously | Immediate movement remains viewport pan; the stationary hold clearly selects erase intent. |
| Trackpad/mouse input | Existing pointer controls | Touch changes must not regress desktop-style play on an attached keyboard and trackpad. Viewport wheel zoom is throttled to one game zoom step per four wheel units. |
| Text field with hardware keyboard attached | Hardware keyboard input | iPadOS normally suppresses its software keyboard while hardware input is available. |
| Native park chrome (park only) | Opens or toggles the matching in-engine windows | Two Liquid Glass layouts: a floating bottom cluster (Trees / Build ride / Paths / More) and a Find My-style inset sheet with Build / Park / View / More tabs. Overflow (…) switches layouts and lists the remaining tools. Hidden on title, loading, and editor scenes. |

## Gesture arbitration

Two-finger gestures begin undecided. A dominant span change becomes pinch; a
dominant angle change becomes construction rotation when the active tool
supports it; otherwise centroid translation becomes viewport pan. Footpath
erase is selected only by holding nearly still over something the engine says
is removable. This keeps the common navigation gestures available without
adding a permanent on-screen mode switch.

One-finger movement never pans the viewport. It either moves a placement
preview, performs a deliberate paint drag after the hold threshold, or drags an
in-game window/control that already supports left-button dragging.

## Device-validation notes

- The July 16 physical-device pass accepted the full mapping above as the
  current control checkpoint. Footpath paint, single-segment removal,
  continuous removal, construction rotation, native conditional text entry,
  trackpad zoom, pan, and pinch all behaved as intended during hands-on play.
- Control feel is a physical-device gate. Thresholds are intentionally kept in
  one place in `src/openrct2-ui/UiContext.cpp` so they can be tuned without
  changing tool behavior.
- Native software-keyboard visibility remains controlled by iPadOS when a
  hardware keyboard is connected. This is expected and preserves attached
  keyboard operation.
- Scenario loading time is not currently changed by the touch layer. Slow-load
  reports should be measured separately before treating them as input debt.

## Change log

### July 16, 2026

- Confirmed native keyboard input works when the hardware keyboard is removed
  and remains conditional when it is attached.
- Reduced placement-twist angle from 20 to 15 degrees and delayed pan
  classification while a rotatable construction tool is active.
- Added two-finger secondary tap and hold-then-drag footpath removal.
- Physically accepted path painting/removal and the 15-degree placement
  rotation behavior without further threshold changes.
- Recorded the complete branch-specific control map and design rationale.

### July 15, 2026

- Replaced the app-owned black keyboard with a native UIKit text-input bridge.
- Widened placement double-tap timing from 300 to 390 ms.
- Added one-finger placement preview movement and hold-then-drag paint tools.
- Added the bounded two-finger construction-rotation prototype.
- Reduced attached-trackpad viewport zoom sensitivity.

### July 14, 2026

- Established inverted half-speed two-finger pan, deliberate pinch
  classification, touch-sized UI scaling, and long-press secondary action.
