# iOS and iPadOS 27 adaptive-window contract

**Decision date:** August 30, 2026  
**Toolchain checked:** Xcode 27.0, iOS 27.0 SDK  
**Status:** Adopted in source; Simulator and physical-device evidence are tracked
in [`DEVELOPMENT-STATUS.md`](DEVELOPMENT-STATUS.md).

## Decision

OpenRCT2 Touch behaves like a regular adaptive app rather than an immersive,
fixed-screen game:

- iPadOS owns the window frame, resize handle, window controls, and Windowed
  Apps mode. The app supplies fluid content at every size and does not draw a
  custom title bar or resize affordance.
- The app has one resizable scene. `UIApplicationSupportsMultipleScenes=false`
  remains intentional: supporting several independently running parks is a
  separate engine-state project, not a prerequisite for resizing one window.
- The SDL Metal canvas fills the current scene. It can extend beneath
  noninteractive system regions, while native park controls use safe,
  horizontally corner-adapted margins so they avoid the status bar, Home
  indicator, rounded corners, resize affordance, and iPad window controls.
- The standard status bar and Home indicator remain visible. System edge
  gestures win on the first swipe; the app does not defer them.
- No arbitrary minimum size is imposed. If testing later establishes a real
  usability floor, use `UIWindowScene.sizeRestrictions.minimumSize` and keep it
  as small as the game can genuinely support.
- The system's automatic window-control style remains in force. Do not set
  `preferredWindowingControlStyleForScene` unless a measured collision remains
  after using corner-adapted layout guides.

This means users can freely resize the universal app on iPadOS. An iPhone
device itself still presents one full-device app at a time. Apple's iOS 27
resizable-iPhone work applies to iPhone Mirroring on Mac and to iPhone apps
running on iPad; the universal build uses native iPad windowing on iPad.

## Why this is Apple's recommended path

Apple deprecated `UIRequiresFullScreen` in iPadOS 26. With the iOS 27 SDK, the
key no longer opts an app out of multitasking; it selects a game-compatibility
mode with discrete resize updates. That mode can be useful when an engine
cannot relayout during a drag, but it directly contradicts this project's fluid
resize goal. The app therefore omits the key, supplies a launch screen, and
declares every supported iPad orientation.

Apple's current layout guidance is size-first and scene-local:

- Use the current view's bounds and size classes for layout, not device type or
  an interface-orientation branch.
- Use the current `UIWindowScene.effectiveGeometry` when window geometry is
  required, and use trait display scale rather than `UIScreen.main.scale`.
- Let backgrounds fill the scene, but place interactive controls inside safe
  areas and corner-adapted margins.
- Continue laying out during an interactive resize. The optional
  `effectiveGeometry.isInteractivelyResizing` signal is for deferring expensive
  asset regeneration, not for freezing ordinary layout.
- Avoid system-edge gesture conflicts. Gesture deferral is reserved for a
  deliberately immersive experience that needs edge input.

The iOS 27 SwiftUI toolbar API also has `ToolbarPlacement.statusBar`, but it is
not the right ownership layer here. SwiftUI hosts several small child overlays;
SDL's UIKit root view controller owns the scene and therefore owns status-bar
appearance. Leaving view-controller-based status-bar appearance enabled gives
the system the standard status bar without inventing a duplicate SwiftUI bar.

## Repository mapping

| Apple contract | OpenRCT2 Touch implementation |
| --- | --- |
| Fluid resizable scene | `UIRequiresFullScreen` is absent from `ios/App/Info.plist`; the app has a launch screen and all iPad orientations. |
| Scene lifecycle | The plist names `SDLUIKitSceneDelegate`; SDL's focused backport creates its `UIWindow` with the active `UIWindowScene`. |
| Live geometry | `UiContext.iOS.mm` reads `effectiveGeometry`, local bounds, safe-area insets, and trait display scale. SDL layout events drive the existing engine resize path, with a per-frame drawable recovery check. |
| Standard status bar | The plist does not force `UIStatusBarHidden` and does not disable view-controller ownership. The SDL window is resizable/high-DPI, not borderless. |
| Regular Home gesture | `SDL_HINT_IOS_HIDE_HOME_INDICATOR` is `"0"`; combined with the non-borderless SDL window, SDL returns no deferred screen edges. |
| Window-control clearance | `ParkChromeHost.swift` anchors interactive park chrome to UIKit's horizontally corner-adapted margins. |
| Regression protection | Source and built-bundle audits reject the deprecated full-screen/status-bar policy; Simulator lifecycle logs require a visible status bar. |

## Validation matrix

Automated checks establish bundle policy, compilation, live resize events, and
status-bar visibility. The final interaction checks are necessarily visual and
physical:

| Host | Required proof |
| --- | --- |
| iPhone Simulator | Portrait and landscape canvas sizes update; status log reports `status_bar_hidden=0`; native chrome remains within safe margins. |
| iPad Simulator / Xcode 27 Device Hub | Drag repeatedly through narrow, wide, tall, half, third, quadrant, and full-screen sizes. The park remains live and chrome remains reachable without overlapping window controls or the resize affordance. |
| Physical iPadOS 27 device | Repeat fluid resize in Windowed Apps mode, rotate, enter/exit full screen, and verify the first upward Home swipe leaves the app normally. |
| Physical iPhone on iOS 27 | Verify time/cellular status UI, visible Home indicator, one-swipe Home behavior, rotation, and no accidental gesture capture near screen edges. |
| iPhone Mirroring on macOS 27 | Resize the mirrored app and verify that live canvas and native chrome track every intermediate size. |

If interactive resizing exposes frame-time spikes, profile before changing the
contract. Expensive texture or asset regeneration may be coalesced while
`isInteractivelyResizing` is true, but input, geometry, and the last valid frame
must continue updating.

## Follow-up UIKit/SDL debt

The current app intentionally supports one scene, and its production layout is
scene-local. The SDL 2.32.10 backport still contains legacy fallback paths that
walk connected scenes or reference `UIScreen.main`, plus app-level lifecycle
observers alongside the new scene callbacks. Those paths do not block this
single-scene resize/status/Home change, but they should be removed from the
tracked vcpkg patch before enabling several independent scenes. In particular,
avoid double-delivering foreground/background events and keep termination and
memory-warning observation.

## Primary sources

- [TN3192: Migrating your app from the deprecated UIRequiresFullScreen key](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)
- [WWDC26: Modernize your UIKit app](https://developer.apple.com/videos/play/wwdc2026/278/)
- [WWDC25: Make your UIKit app more flexible](https://developer.apple.com/videos/play/wwdc2025/282/)
- [WWDC25: Elevate the design of your iPad app](https://developer.apple.com/videos/play/wwdc2025/208/)
- [Human Interface Guidelines: Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [Human Interface Guidelines: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Human Interface Guidelines: Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking)
- [Human Interface Guidelines: Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures)
- [`preferredScreenEdgesDeferringSystemGestures`](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredscreenedgesdeferringsystemgestures)
- [`prefersHomeIndicatorAutoHidden`](https://developer.apple.com/documentation/uikit/uiviewcontroller/prefershomeindicatorautohidden)
- [`UIWindowScene.effectiveGeometry`](https://developer.apple.com/documentation/uikit/uiwindowscene/effectivegeometry)
- [`ToolbarPlacement.statusBar`](https://developer.apple.com/documentation/swiftui/toolbarplacement/statusbar)
- [SDL iOS Home-indicator hint](https://wiki.libsdl.org/SDL2/SDL_HINT_IOS_HIDE_HOME_INDICATOR)

Installed Apple-authored guidance was also checked: the iOS 27 SwiftUI change
catalog and toolbar reference, Apple's SwiftUI toolbar documentation extracted
from Xcode, and the UIKit app-modernization audit covering scene lifecycle,
`UIScreen.main`, adaptive layout, and safe areas.
