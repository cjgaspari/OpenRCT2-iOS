# research/mac-liquid-glass

Mac-native Liquid Glass park chrome on the **existing desktop macOS build**, not the iPhone/Touch app.

| | |
| --- | --- |
| **Base tip** | `origin/touch/public-hygiene` @ `341afaa0a3` (chrome *roles* reference only) |
| **Pipeline** | `scripts/build-macos.sh` → Ninja `openrct2` (`MACOS_BUNDLE=OFF`) → `scripts/run-macos.sh` |
| **Windowing** | SDL desktop: `SDL_WINDOW_RESIZABLE \| ALLOW_HIGHDPI`, default 1280×720, min 720×480; resize via normal `OnResize` (not iOS canvas) |
| **Host** | `IPlatformUiContext::AttachNativeOverlay` → SDL Cocoa `NSWindow.contentView` → pass-through `NSView` + `NSHostingView` |
| **Deploy** | macOS **27.0+** / Xcode 27 SDK |
| **Not used** | Mac Catalyst, `ios/platform/chrome/*` UIKit hosts, Touch CMake `OPENRCT2_IOS` |

## Build & run (this MacBook Air)

```bash
./scripts/build-macos.sh
SKIP_BUILD=1 ./scripts/run-macos.sh path/to/park.sv6
```

Overlay attaches when the desktop binary creates its SDL window. Engine toolbars still coexist (policy TBD).
