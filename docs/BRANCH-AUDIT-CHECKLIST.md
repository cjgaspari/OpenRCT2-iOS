# OpenRCT2 Touch branch audit checklist

This checklist records the current audit plan for the iPhone support, dynamic
windowing, native scenario picker, native park chrome, and related iOS branch
changes.

Recent `touch/ios27-windowing` changes strengthen the adaptive-windowing
assessment, but expand the native presentation surface area. This checklist now
treats native load/save and the shared modal host/bridge layer as first-class
audit targets alongside the scenario picker.

## Build system and platform split

### `CMakeLists.txt`

- Verify the Apple-platform split is minimal and clean (`OPENRCT2_IOS` vs `OPENRCT2_MACOS`).
- Confirm no macOS-only behavior leaks into iOS builds.
- Confirm iOS defaults disable only what is necessary (`HTTP`, `network`, `OpenGL`, audio codecs).
- Check whether any of these defaults should stay user-configurable upstream.
- Keep: yes.
- Upstreamability: high.

### `src/openrct2/CMakeLists.txt`

- Verify adding `/ios/platform/Platform.iOS.mm` is the smallest way to register iOS.
- Confirm the static-linking choice is justified on Apple platforms.
- Check whether iOS source inclusion should live nearer `src/openrct2/platform/`.
- Keep: yes.
- Simplify: maybe move file ownership and registration closer to the platform tree.
- Upstreamability: high.

### `src/openrct2-ui/CMakeLists.txt`

- Verify the iOS UI static-library split is necessary for SDL and UIKit bootstrap.
- Confirm Swift sources are limited to the overlay and picker.
- Confirm `-parse-as-library` and `LINKER_LANGUAGE CXX` are documented and required.
- Check whether a Swift dependency is acceptable upstream.
- Keep: yes.
- Risk: a Swift requirement may block upstream acceptance.

### `ios/CMakeLists.txt`

- Verify the app target is thin and only hosts SDL plus bundle resources.
- Confirm no product decisions are mixed into engine plumbing.
- Check whether `openrct2-touch` target naming is fork-only.
- Keep: for the fork, yes.
- Upstreamability: medium.

### `cmake/platform.cmake`

- Confirm UIKit, CoreText, and Foundation links are the minimum needed.
- Check whether more explicit per-target linking would be clearer.
- Keep: yes.

## App shell, lifecycle, and scene ownership

### `ios/App/Info.plist`

- Confirm scene lifecycle keys are correct.
- Confirm the iPhone and iPad orientation contract matches the intended product.
- Confirm status-bar and Home-indicator behavior follows Apple guidance.
- Confirm the adaptive iOS 27 contract is intentional, documented, and
  consistent with `docs/IOS-27-WINDOWING.md`.
- Verify the app remains single-scene by design, rather than by omission.
- Confirm nothing here is fork-branding-specific if upstreaming.
- Keep: yes.
- Upstreamability: high for the iOS port, low for branding details.

### `ios/App/AppLifecycle.iOS.mm`

- Verify lifecycle logging is still needed in production.
- Check whether this should be debug-only.
- Confirm there are no duplicate scene and app lifecycle events.
- Audit whether app-level lifecycle observation is still appropriate now that
  the branch relies on `UIScene` lifecycle semantics.
- Confirm lifecycle logging does not duplicate scene-driven behavior or mask SDL
  lifecycle debt.
- Keep: maybe.
- Simplify: likely gate or reduce logging.

## Core iOS platform support

### `ios/platform/Platform.iOS.mm`

- Confirm sandbox paths are correct and minimal.
- Confirm bundle and Documents lookup matches app behavior.
- Confirm locale and font helpers are reusable and do not duplicate macOS unnecessarily.
- Keep: yes.
- Upstreamability: high.

### `ios/platform/UiContext.iOS.mm`

- Confirm UIKit usage here is strictly bridge-layer only.
- Audit window and scene selection logic for duplication with other files.
- Confirm scene-local geometry and safe-area lookup are the canonical source of
  truth for iOS 27 resizing.
- Audit duplicated `connectedScenes` and active-window lookup logic across
  `UiContext.iOS.mm`, `RCT2Importer.iOS.mm`, and `NativeChrome.iOS.mm`.
- Audit text-input bridge lifetime and responder behavior.
- Confirm the file-picker hook is routed correctly.
- Keep: yes.
- Simplify: centralize window and scene lookup helpers.

### `src/openrct2-ui/UiContext.h`

- Confirm the platform hook surface is minimal (`AttachNativeOverlay`, `HandleSdlEvent`, `TickNativeOverlay`).
- Check whether overlay-specific hooks are too opinionated for a generic UI context.
- Keep: yes.

## Rendering, resize, and windowing

### `src/openrct2-ui/UiContext.cpp`

- Separate iOS touch logic from generic SDL and UI lifecycle logic.
- Verify iOS resize persistence exceptions are minimal.
- Confirm iOS-specific code paths do not degrade desktop behavior.
- Keep: mostly yes.
- Simplify: high priority; split the iOS gesture classifier into dedicated source files.

### `src/openrct2-ui/drawing/engines/HardwareDisplayDrawingEngine.cpp`

- Confirm Metal renderer enforcement is necessary.
- Audit rotation and recovery code for SDL workaround versus permanent architecture.
- Reassess whether current iOS drawable recovery logic is a temporary SDL
  workaround or an intentional long-term renderer contract.
- Confirm windowing fixes do not regress performance during interactive resize.
- Check whether any logging can be reduced after stabilization.
- Keep: yes.
- Upstreamability: high if framed as an iOS renderer fix.

### `src/openrct2-ui/IosSafeArea.h`

- Confirm this stays as a tiny shared contract.
- Check whether it should live under platform-specific headers.
- Keep: yes.

### `src/openrct2-ui/WindowManager.cpp`

- Audit iOS auto-centering and clamping behavior for all oversized windows.
- Confirm this is a generic mobile improvement, not just a scenario-picker workaround.
- Keep: yes.

### `src/openrct2/interface/Window.cpp`

- Confirm a toolbar offset of `0` on iOS is correct everywhere.
- Audit title-screen and centred-window relocation for unintended side effects.
- Keep: yes.

## Import, sandbox, and Files flow

### `ios/platform/RCT2Importer.iOS.mm`

- Confirm Files import behavior is correct for RCT2 and RCT Classic.
- Audit security-scoped resource handling.
- Audit temp and backup cleanup paths.
- Confirm no proprietary data escapes sandbox and import rules.
- Check whether any presentation logic should move into a reusable UIKit helper.
- Keep: yes.
- Upstreamability: high.

## Native chrome bridge

### `ios/platform/NativeChrome.iOS.mm`

- Audit whether this file has become a generic native modal and chrome
  dispatcher rather than a thin bridge.
- Separate responsibilities for:
  - overlay attach and detach
  - park chrome state sync
  - scenario picker presentation
  - load/save presentation
  - action routing
  - window-centering policy
- Confirm modal routing remains consistent when multiple native surfaces are
  possible.
- Verify all native controls map to existing in-engine intents only.
- Confirm no duplicated game logic lives here.
- Review whether polling in `NativeChromeTick()` should become a cleaner
  state-sync layer.
- Check whether `NativeChromeTick()` is accumulating product logic that should
  move elsewhere.
- Keep: yes, but split.
- Simplify: highest priority.
- Upstreamability: medium to low until responsibilities are separated.

### `ios/platform/chrome/ParkChromeActions.h`

### `ios/platform/chrome/ParkChromeActions.swift`

- Confirm the action enum is stable and minimal.
- Confirm the action space is still coherent as native surfaces expand.
- Check for duplication between the C++ and Swift definitions.
- Audit whether action IDs are becoming an ad hoc protocol between too many
  systems.
- Check whether load/save and scenario-picker actions should be grouped or
  mechanically generated.
- Keep: yes.
- Simplify: use a generated or shared definition if practical.

## SwiftUI chrome

### `ios/platform/chrome/ParkChromeModel.swift`

- Confirm the model holds only view state, not platform-specific types.
- Audit `UserDefaults` persistence scope.
- Confirm the remaining model is mostly view state after the recent
  pause/resume cleanup.
- Audit whether any remaining control-policy decisions should move out of the
  model.
- Keep: yes.

### `ios/platform/chrome/ParkMenuCatalog.swift`

- Confirm menu contents are declarative and do not duplicate engine metadata too much.
- Check whether titles and icons are too product-specific for upstream.
- Keep: yes for the fork.
- Upstreamability: medium.

### `ios/platform/chrome/GlassChrome.swift`

- Audit use of iOS-only glass APIs.
- Separate reusable layout and components from iOS-specific styling.
- Check whether macOS reuse would require only style swaps.
- Confirm the updated pause/speed and menu behavior keeps the chrome as a thin
  controller rather than embedding gameplay policy.
- Audit where menu semantics are now cleaner after removing implicit
  pause/resume.
- Keep: yes.
- Simplify: extract platform-neutral view structure from the style layer.

### `ios/platform/chrome/ParkChromeRootView.swift`

- Confirm the root layout is simple and only composes subviews.
- Check whether sheet scaffolding belongs in a separate reusable file.
- Keep: yes.

### `ios/platform/chrome/ParkChromeHost.swift`

- Audit UIKit hosting and controller logic for duplication.
- Audit whether this file has become a generic native host and container for
  multiple SwiftUI modal systems.
- Confirm this is the only place SwiftUI depends on UIKit hosting.
- Check whether scenario picker and load/save hosting should share reusable host
  types or layout helpers.
- Confirm view visibility and hit-testing rules remain correct when chrome,
  scenario picker, and load/save overlap.
- Keep: yes.
- Simplify: highest priority.

## Native scenario picker

### `ios/platform/NativeScenarioPicker.iOS.mm`

- Identify duplicated logic already present in desktop `ScenarioSelect.cpp`.
- Extract a shared scenario snapshot builder in C++ if possible.
- Audit this file together with `ios/platform/NativeLoadSave.iOS.mm` as part of
  a growing native modal layer.
- Check whether shared snapshot building, selection state, and preview and
  update plumbing can be abstracted across native modal wrappers.
- Keep the native layer focused on presentation plus preview loading only.
- Keep: maybe.
- Simplify: highest priority.
- Upstreamability: medium until deduplicated.

### `ios/platform/NativeLoadSave.iOS.h`

- Confirm the public native load/save API is minimal and does not leak
  unnecessary UI assumptions.
- Check whether it matches the same abstraction style as the native scenario
  picker.

### `ios/platform/NativeLoadSave.iOS.mm`

- Identify duplicated logic already present in
  `src/openrct2-ui/interface/FileBrowser.cpp`.
- Confirm callback lifetime and path ownership are safe.
- Audit whether save-name commit, overwrite selection, and file scanning belong
  in shared logic instead of the native wrapper.
- Check whether native load/save and native scenario picker should share a
  common snapshot and presentation framework.
- Keep: maybe.
- Simplify: highest priority.
- Upstreamability: medium to low until deduplicated.

### `ios/platform/chrome/ScenarioPickerModel.swift`

- Remove UIKit dependency if possible.
- Replace `UIImage?` with `CGImage?` or a platform-neutral pixel payload.
- Confirm the model is platform-neutral view state only.
- Keep: yes.
- Simplify: high priority.

### `ios/platform/chrome/ScenarioPickerView.swift`

- Confirm adaptive layout is good enough for both iPhone and iPad.
- Check whether the compact and column split is reusable on macOS.
- Audit whether any strings or behaviors duplicate desktop logic unnecessarily.
- Keep: yes.

### `ios/platform/chrome/LoadSaveModel.swift`

- Confirm the model is pure view state.
- Audit whether overwrite and save-name matching logic belongs in shared domain
  logic instead of the view model.
- Check whether this model duplicates patterns that should be shared with
  `ScenarioPickerModel.swift`.
- Keep: yes.
- Simplify: medium to high priority.

### `ios/platform/chrome/LoadSaveView.swift`

- Confirm this is a reusable native modal view pattern, not a one-off
  implementation.
- Check whether the sheet presentation, list structure, and confirmation flow
  should be generalized with the scenario picker host.
- Audit whether the current save/load UX is fork-only product policy or
  intended iOS platform policy.
- Keep: yes for the fork.
- Upstreamability: medium.

## Engine UI files with iOS bypasses

### `src/openrct2-ui/windows/ScenarioSelect.cpp`

- Confirm the iOS hook cleanly swaps the native picker for the desktop window.
- Minimize divergence from the desktop path.
- Keep: yes.

### `src/openrct2-ui/interface/FileBrowser.cpp`

- Confirm the iOS native load/save interception point is the correct abstraction
  boundary.
- Audit whether platform dispatch now belongs in a cleaner adapter layer.
- Verify built-in desktop behavior remains unchanged.
- Keep: yes.
- Simplify: medium.

### `src/openrct2-ui/windows/TopToolbar.cpp`

### `src/openrct2-ui/windows/GameBottomToolbar.cpp`

### `src/openrct2-ui/windows/EditorBottomToolbar.cpp`

### `src/openrct2-ui/windows/ParkInfoPanel.cpp`

### `src/openrct2-ui/windows/DateInfoPanel.cpp`

- Confirm iOS returning `nullptr` is the right abstraction.
- Check whether a higher-level mobile-toolbar suppression policy would be cleaner.
- Keep: functionally yes.
- Simplify: replace scattered `TARGET_OS_IOS` early returns with one policy layer if practical.

## Docs, workflows, and safety

### `docs/DEVELOPMENT-STATUS.md`

### `docs/IOS-27-WINDOWING.md`

### `docs/TOUCH-CONTROLS.md`

### `docs/README-touch.md`

### `readme.md`

- Verify claims match shipped behavior.
- Remove any stale checkpoints.
- Separate fork-facing docs from anything intended for upstream submission.
- Keep: yes for the fork.
- Upstreamability: low.

### `scripts/check-touch-release-safety.sh`

### `scripts/verify-ios-bundle.sh`

### `scripts/build-ios.sh`

### `.github/workflows/ios-device.yml`

### `.github/workflows/touch-release-safety.yml`

- Confirm checks enforce the real asset and licensing boundary.
- Confirm they are fork-safe and not upstream noise.
- Reduce any product-specific policy embedded in build verification if upstreaming.
- Keep: yes for the fork.
- Upstreamability: low to medium.

## Top simplification targets

1. `ios/platform/NativeChrome.iOS.mm`
2. `ios/platform/chrome/ParkChromeHost.swift`
3. `ios/platform/NativeScenarioPicker.iOS.mm`
4. `ios/platform/NativeLoadSave.iOS.mm`
5. `src/openrct2-ui/interface/FileBrowser.cpp`
6. `src/openrct2-ui/UiContext.cpp`
7. `ios/platform/chrome/ScenarioPickerModel.swift`
8. `ios/platform/chrome/LoadSaveModel.swift`

## Note on avoiding `UIImage`

If the branch removes `UIImage` from the SwiftUI scenario picker model, the most
direct replacement is `CGImage`.

- Store `CGImage?` in the model rather than `UIImage?`.
- Build the SwiftUI image in the view from that `CGImage`.
- If further portability is needed, store raw RGBA data or a small preview
  struct and construct the `CGImage` in a shared helper.

This keeps UIKit out of the model layer and improves macOS reuse potential.

## Closing note

- The iOS 27 adaptive-window direction is now more strongly validated.
- The main remaining architecture question is no longer whether native overlays
  should exist, but how to prevent native scenario picker, load/save, and park
  chrome from becoming three parallel presentation stacks.
