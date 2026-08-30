# OpenRCT2 Touch branch audit checklist

This checklist records the current audit plan for the iPhone support, dynamic
windowing, native scenario picker, native park chrome, and related iOS branch
changes.

## Build system and platform split

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/CMakeLists.txt`

- Verify the Apple-platform split is minimal and clean (`OPENRCT2_IOS` vs `OPENRCT2_MACOS`).
- Confirm no macOS-only behavior leaks into iOS builds.
- Confirm iOS defaults disable only what is necessary (`HTTP`, `network`, `OpenGL`, audio codecs).
- Check whether any of these defaults should stay user-configurable upstream.
- Keep: yes.
- Upstreamability: high.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2/CMakeLists.txt`

- Verify adding `/ios/platform/Platform.iOS.mm` is the smallest way to register iOS.
- Confirm the static-linking choice is justified on Apple platforms.
- Check whether iOS source inclusion should live nearer `src/openrct2/platform/`.
- Keep: yes.
- Simplify: maybe move file ownership and registration closer to the platform tree.
- Upstreamability: high.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/CMakeLists.txt`

- Verify the iOS UI static-library split is necessary for SDL and UIKit bootstrap.
- Confirm Swift sources are limited to the overlay and picker.
- Confirm `-parse-as-library` and `LINKER_LANGUAGE CXX` are documented and required.
- Check whether a Swift dependency is acceptable upstream.
- Keep: yes.
- Risk: a Swift requirement may block upstream acceptance.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/CMakeLists.txt`

- Verify the app target is thin and only hosts SDL plus bundle resources.
- Confirm no product decisions are mixed into engine plumbing.
- Check whether `openrct2-touch` target naming is fork-only.
- Keep: for the fork, yes.
- Upstreamability: medium.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/cmake/platform.cmake`

- Confirm UIKit, CoreText, and Foundation links are the minimum needed.
- Check whether more explicit per-target linking would be clearer.
- Keep: yes.

## App shell, lifecycle, and scene ownership

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/App/Info.plist`

- Confirm scene lifecycle keys are correct.
- Confirm the iPhone and iPad orientation contract matches the intended product.
- Confirm status-bar and Home-indicator behavior follows Apple guidance.
- Confirm nothing here is fork-branding-specific if upstreaming.
- Keep: yes.
- Upstreamability: high for the iOS port, low for branding details.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/App/AppLifecycle.iOS.mm`

- Verify lifecycle logging is still needed in production.
- Check whether this should be debug-only.
- Confirm there are no duplicate scene and app lifecycle events.
- Keep: maybe.
- Simplify: likely gate or reduce logging.

## Core iOS platform support

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/Platform.iOS.mm`

- Confirm sandbox paths are correct and minimal.
- Confirm bundle and Documents lookup matches app behavior.
- Confirm locale and font helpers are reusable and do not duplicate macOS unnecessarily.
- Keep: yes.
- Upstreamability: high.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/UiContext.iOS.mm`

- Confirm UIKit usage here is strictly bridge-layer only.
- Audit window and scene selection logic for duplication with other files.
- Audit text-input bridge lifetime and responder behavior.
- Confirm the file-picker hook is routed correctly.
- Keep: yes.
- Simplify: centralize window and scene lookup helpers.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/UiContext.h`

- Confirm the platform hook surface is minimal (`AttachNativeOverlay`, `HandleSdlEvent`, `TickNativeOverlay`).
- Check whether overlay-specific hooks are too opinionated for a generic UI context.
- Keep: yes.

## Rendering, resize, and windowing

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/UiContext.cpp`

- Separate iOS touch logic from generic SDL and UI lifecycle logic.
- Verify iOS resize persistence exceptions are minimal.
- Confirm iOS-specific code paths do not degrade desktop behavior.
- Keep: mostly yes.
- Simplify: high priority; split the iOS gesture classifier into dedicated source files.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/drawing/engines/HardwareDisplayDrawingEngine.cpp`

- Confirm Metal renderer enforcement is necessary.
- Audit rotation and recovery code for SDL workaround versus permanent architecture.
- Check whether any logging can be reduced after stabilization.
- Keep: yes.
- Upstreamability: high if framed as an iOS renderer fix.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/IosSafeArea.h`

- Confirm this stays as a tiny shared contract.
- Check whether it should live under platform-specific headers.
- Keep: yes.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/WindowManager.cpp`

- Audit iOS auto-centering and clamping behavior for all oversized windows.
- Confirm this is a generic mobile improvement, not just a scenario-picker workaround.
- Keep: yes.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2/interface/Window.cpp`

- Confirm a toolbar offset of `0` on iOS is correct everywhere.
- Audit title-screen and centred-window relocation for unintended side effects.
- Keep: yes.

## Import, sandbox, and Files flow

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/RCT2Importer.iOS.mm`

- Confirm Files import behavior is correct for RCT2 and RCT Classic.
- Audit security-scoped resource handling.
- Audit temp and backup cleanup paths.
- Confirm no proprietary data escapes sandbox and import rules.
- Check whether any presentation logic should move into a reusable UIKit helper.
- Keep: yes.
- Upstreamability: high.

## Native chrome bridge

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/NativeChrome.iOS.mm`

- Audit whether this file mixes too many concerns:
  - SDL event bridge
  - park-state polling
  - window centering
  - action dispatch
  - attach and detach lifecycle
- Verify all native controls map to existing in-engine intents only.
- Confirm no duplicated game logic lives here.
- Review whether polling in `NativeChromeTick()` should become a cleaner state-sync layer.
- Keep: yes.
- Simplify: high priority; split into bridge, state, and action helpers.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeActions.h`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeActions.swift`

- Confirm the action enum is stable and minimal.
- Check for duplication between the C++ and Swift definitions.
- Keep: yes.
- Simplify: use a generated or shared definition if practical.

## SwiftUI chrome

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeModel.swift`

- Confirm the model holds only view state, not platform-specific types.
- Audit `UserDefaults` persistence scope.
- Check whether pause and resume behavior belongs here or in the action layer.
- Keep: yes.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkMenuCatalog.swift`

- Confirm menu contents are declarative and do not duplicate engine metadata too much.
- Check whether titles and icons are too product-specific for upstream.
- Keep: yes for the fork.
- Upstreamability: medium.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/GlassChrome.swift`

- Audit use of iOS-only glass APIs.
- Separate reusable layout and components from iOS-specific styling.
- Check whether macOS reuse would require only style swaps.
- Keep: yes.
- Simplify: extract platform-neutral view structure from the style layer.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeRootView.swift`

- Confirm the root layout is simple and only composes subviews.
- Check whether sheet scaffolding belongs in a separate reusable file.
- Keep: yes.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeHost.swift`

- Audit UIKit hosting and controller logic for duplication.
- Confirm this is the only place SwiftUI depends on UIKit hosting.
- Check whether the scenario picker host and park chrome host can share adapter code.
- Keep: yes.
- Simplify: high priority.

## Native scenario picker

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/NativeScenarioPicker.iOS.mm`

- Identify duplicated logic already present in desktop `ScenarioSelect.cpp`.
- Extract a shared scenario snapshot builder in C++ if possible.
- Keep the native layer focused on presentation plus preview loading only.
- Keep: maybe.
- Simplify: highest priority.
- Upstreamability: medium until deduplicated.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ScenarioPickerModel.swift`

- Remove UIKit dependency if possible.
- Replace `UIImage?` with `CGImage?` or a platform-neutral pixel payload.
- Confirm the model is platform-neutral view state only.
- Keep: yes.
- Simplify: high priority.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ScenarioPickerView.swift`

- Confirm adaptive layout is good enough for both iPhone and iPad.
- Check whether the compact and column split is reusable on macOS.
- Audit whether any strings or behaviors duplicate desktop logic unnecessarily.
- Keep: yes.

## Engine UI files with iOS bypasses

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/ScenarioSelect.cpp`

- Confirm the iOS hook cleanly swaps the native picker for the desktop window.
- Minimize divergence from the desktop path.
- Keep: yes.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/TopToolbar.cpp`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/GameBottomToolbar.cpp`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/EditorBottomToolbar.cpp`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/ParkInfoPanel.cpp`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/windows/DateInfoPanel.cpp`

- Confirm iOS returning `nullptr` is the right abstraction.
- Check whether a higher-level mobile-toolbar suppression policy would be cleaner.
- Keep: functionally yes.
- Simplify: replace scattered `TARGET_OS_IOS` early returns with one policy layer if practical.

## Docs, workflows, and safety

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/docs/DEVELOPMENT-STATUS.md`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/docs/IOS-27-WINDOWING.md`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/docs/TOUCH-CONTROLS.md`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/docs/README-touch.md`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/readme.md`

- Verify claims match shipped behavior.
- Remove any stale checkpoints.
- Separate fork-facing docs from anything intended for upstream submission.
- Keep: yes for the fork.
- Upstreamability: low.

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/scripts/check-touch-release-safety.sh`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/scripts/verify-ios-bundle.sh`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/scripts/build-ios.sh`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/.github/workflows/ios-device.yml`

### `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/.github/workflows/touch-release-safety.yml`

- Confirm checks enforce the real asset and licensing boundary.
- Confirm they are fork-safe and not upstream noise.
- Reduce any product-specific policy embedded in build verification if upstreaming.
- Keep: yes for the fork.
- Upstreamability: low to medium.

## Top simplification targets

1. `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/NativeScenarioPicker.iOS.mm`
2. `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/src/openrct2-ui/UiContext.cpp`
3. `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/NativeChrome.iOS.mm`
4. `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ParkChromeHost.swift`
5. `/home/runner/work/OpenRCT2-iOS/OpenRCT2-iOS/ios/platform/chrome/ScenarioPickerModel.swift`

## Note on avoiding `UIImage`

If the branch removes `UIImage` from the SwiftUI scenario picker model, the most
direct replacement is `CGImage`.

- Store `CGImage?` in the model rather than `UIImage?`.
- Build the SwiftUI image in the view from that `CGImage`.
- If further portability is needed, store raw RGBA data or a small preview
  struct and construct the `CGImage` in a shared helper.

This keeps UIKit out of the model layer and improves macOS reuse potential.
