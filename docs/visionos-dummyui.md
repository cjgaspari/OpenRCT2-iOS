# DummyUiContext Implementation Spec for visionOS

## 1. Overview

### 1.1 Purpose
The `DummyUiContext` is a visionOS-specific implementation of the `IUiContext` interface designed to replace the SDL-based `UiContext` in environments where SDL is disabled (`DISABLE_SDL=1`). visionOS uses native RealityKit/Metal for rendering and input, so traditional SDL windowing and event handling are not applicable. The `DummyUiContext` provides stub implementations that allow OpenRCT2's core logic to run without SDL dependencies, while delegating actual UI/rendering to the Swift-side `MetalLayerView` and visionOS frameworks.

### 1.2 Scope
- **In Scope**: Implement all methods of `IUiContext` with minimal/no-op logic where possible, ensuring OpenRCT2 initializes and runs its game loop without crashing or failing due to missing UI primitives.
- **Out of Scope**: Actual window creation, input handling, or rendering—these are handled natively in Swift (e.g., via `CAMetalLayer` and `CADisplayLink`).
- **Goal**: Enable the GUI to "run" in the sense that OpenRCT2's internal state (e.g., scenes, windows, drawing) operates as if on an SDL platform, but with visionOS-specific adaptations (e.g., fixed screen dimensions, no-op input).

### 1.3 Assumptions
- visionOS builds have `OPENRCT2_VISIONOS` defined, allowing conditional compilation.
- The Swift app (`MetalLayerView`) handles real windowing, rendering, and input; `DummyUiContext` only provides the C++ interface stubs.
- Screen size is fixed or queried from Swift (e.g., via a callback or config), as visionOS doesn't have resizable windows.
- No file dialogs, message boxes, or OS-level UI on visionOS (app store compliance); these can be no-ops or log warnings.

## 2. Requirements

### 2.1 Functional Requirements
- **Initialization**: `DummyUiContext` must allow `Context::Initialise()` to succeed by providing a valid `IUiContext` instance.
- **Window Management**: Stub `CreateWindow()`, `CloseWindow()`, etc., to avoid SDL calls. Assume the "window" is always "created" and focused.
- **Input Handling**: Provide dummy input state (e.g., no keys pressed, no cursor movement) since input is handled in Swift.
- **Rendering**: Return a dummy or no-op `IDrawingEngineFactory` (e.g., software rendering stub) to satisfy drawing engine initialization.
- **Screen Properties**: Return fixed or configurable width/height (e.g., 1280x720) to match visionOS app expectations.
- **Event Processing**: `ProcessMessages()` should be a no-op, as events are polled in Swift.
- **Compatibility**: Mimic SDL behavior where possible (e.g., return plausible defaults) to avoid breaking OpenRCT2's logic.

### 2.2 Non-Functional Requirements
- **Performance**: Minimal overhead; methods should be lightweight.
- **Memory**: No significant allocations; use static or minimal state.
- **Thread Safety**: Assume single-threaded usage (main thread only).
- **Logging**: Use visionOS `os_log` for debug info in key methods.
- **Error Handling**: Gracefully handle unsupported operations (e.g., log and return defaults).

### 2.3 Dependencies
- **Headers**: Include `UiContext.h`, `DrawingEngineFactory.hpp`, and visionOS-specific headers (`visionos.h` for macros).
- **Libraries**: No additional libs; relies on standard C++ and OpenRCT2 core.
- **Conditional Compilation**: Wrap in `#ifdef OPENRCT2_VISIONOS` to avoid affecting other platforms.

## 3. Design

### 3.1 Class Structure
```cpp
namespace OpenRCT2::Ui
{
    class DummyUiContext final : public IUiContext
    {
    private:
        // Minimal state: fixed screen size, dummy flags
        int32_t _width = 1280;  // Default visionOS resolution
        int32_t _height = 720;
        bool _hasFocus = true;  // Assume always focused
        ScaleQuality _scaleQuality = ScaleQuality::NearestNeighbour;

    public:
        // Constructor: No args needed
        DummyUiContext();

        // Implement all IUiContext methods (see Section 4)
        // ...
    };

    // Factory function
    std::unique_ptr<IUiContext> CreateDummyUiContext();
}
```

### 3.2 Inheritance and Interfaces
- Inherits from `IUiContext` (defined in `UiContext.h`).
- Does not inherit from `UiContext` (SDL-based); it's a clean stub.
- Key interfaces: `IWindowManager`, `IDrawingEngineFactory` – provide dummy implementations or return nullptr where safe.

### 3.3 Key Design Decisions
- **Fixed Dimensions**: visionOS apps have fixed or immersive views; hardcode defaults but allow override via config or Swift callback.
- **No-Op Input**: Input is external; methods like `GetKeysState()` return empty arrays.
- **Drawing Engine**: Return a software drawing engine factory to allow `InitialiseDrawingEngine()` to succeed.
- **Window Manager**: Return a minimal `IWindowManager` stub (or integrate with existing dummy if available).
- **Platform UI**: `IPlatformUiContext` can be a no-op or minimal implementation.

## 4. Implementation Details

### 4.1 Core Methods
Implement each `IUiContext` method as follows:

- **void InitialiseScriptExtensions()**: Call `Scripting::UiScriptExtensions::Extend(scriptEngine);` if scripting is enabled (same as SDL version).
- **void Tick()**: No-op or minimal (e.g., update in-game console if present).
- **void Draw(RenderTarget& rt)**: No-op; drawing is handled in Swift.
- **void* GetWindow()**: Return `nullptr`; no SDL window.
- **int32_t GetWidth()/GetHeight()**: Return `_width`/`_height`.
- **ScaleQuality GetScaleQuality()**: Return `_scaleQuality`.
- **void SetFullscreenMode(FullscreenMode mode)**: No-op; log mode.
- **const std::vector<Resolution>& GetFullscreenResolutions()**: Return empty vector.
- **bool HasFocus()**: Return `true`.
- **bool IsMinimised()**: Return `false`.
- **bool IsSteamOverlayActive()**: Return `false`.
- **const CursorState* GetCursorState()**: Return a static dummy `CursorState` (no movement).
- **const uint8_t* GetKeysState()**: Return a static empty array.
- **const uint8_t* GetKeysPressed()**: Return a static empty array.
- **CursorID GetCursor()**: Return default cursor ID.
- **void SetCursor(CursorID cursor)**: No-op.
- **void SetCursorScale(uint8_t scale)**: No-op.
- **void SetCursorVisible(bool value)**: No-op.
- **ScreenCoordsXY GetCursorPosition()**: Return {0, 0}.
- **void SetCursorPosition(const ScreenCoordsXY& pos)**: No-op.
- **void SetCursorTrap(bool value)**: No-op.
- **void SetKeysPressed(uint32_t keysym, uint8_t scancode)**: No-op.
- **std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory()**: Return `std::make_shared<DummyDrawingEngineFactory>()` (see below).
- **void DrawWeatherAnimation(...)**: No-op.
- **bool IsTextInputActive()**: Return `false`.
- **TextInputSession* StartTextInput(...) / void StopTextInput()**: Return `nullptr` / no-op.
- **void ProcessMessages()**: No-op; events polled in Swift.
- **void TriggerResize()**: No-op.
- **void CreateWindow()**: Set a flag (e.g., `_windowCreated = true`); log success.
- **void CloseWindow() / void RecreateWindow()**: No-op.
- **void ShowMessageBox(const std::string& message)**: Log the message (no UI popup).
- **int32_t ShowMessageBox(...) / int32_t ShowMenuDialog(...) / void OpenFolder(...) / void OpenURL(...) / std::string ShowFileDialog(...) / std::string ShowDirectoryDialog(...) / bool HasFilePicker()**: Log and return defaults (e.g., empty string, false).
- **IWindowManager* GetWindowManager()**: Return a new `DummyWindowManager` (stub implementation).

### 4.2 Supporting Classes
- **DummyDrawingEngineFactory**: Implement `IDrawingEngineFactory` to return a software drawing engine. Use existing `DrawingEngineFactory` but force software mode.
- **DummyWindowManager**: Stub `IWindowManager` with no-op methods (e.g., `Init()`, `UpdateMapTooltip()` do nothing).
- **DummyPlatformUiContext**: Stub `IPlatformUiContext` with no-ops.

### 4.3 VisionOS-Specific Adaptations
- Use `VISIONOS_LOG_INFO` for key operations (e.g., "DummyUiContext: CreateWindow called").
- For screen size, consider a config option or Swift callback to set `_width`/`_height` dynamically.
- Ensure no SDL includes are pulled in (guarded by `#ifndef DISABLE_SDL`).

## 5. Integration

### 5.1 Code Placement
- Add `DummyUiContext.cpp` and `DummyUiContext.h` in `src/openrct2-ui/`.
- Update `UiContext.h` to declare `CreateDummyUiContext()`.
- In `Context.cpp`, modify `CreateContext()`:
  ```cpp
  #ifdef OPENRCT2_VISIONOS
      auto uiContext = CreateDummyUiContext();
  #else
      auto uiContext = CreateUiContext(*env);
  #endif
  ```

### 5.2 Build System
- Add to `CMakeLists.txt` in `src/openrct2-ui/`: Conditionally compile `DummyUiContext.cpp` for visionOS.
- Ensure visionOS toolchain excludes SDL sources.

## 6. Testing and Validation

### 6.1 Unit Tests
- Test factory creation and basic method calls.
- Verify no crashes in `Context::Initialise()` with `DummyUiContext`.

### 6.2 Integration Tests
- Build and run on visionOS simulator/device.
- Check logs: `Context::Initialise()` should reach "SUCCESS" without SDL errors.
- Verify game loop starts (e.g., `openrct2_init_full` succeeds in Swift).

### 6.3 Validation Criteria
- No SDL-related crashes or logs.
- OpenRCT2 initializes repositories, loads graphics, and enters game loop.
- Swift-side rendering works (framebuffer populated).

## 7. Risks and Mitigations

### 7.1 Risks
- **Incomplete Stubs**: Missing implementations could cause runtime failures (e.g., if OpenRCT2 expects real input).
- **Performance**: If methods are called frequently, ensure they're fast.
- **Compatibility**: Future OpenRCT2 changes to `IUiContext` may break stubs.

### 7.2 Mitigations
- Thoroughly review `IUiContext` usage in codebase.
- Add assertions or logs for unimplemented paths.
- Maintain parity with SDL version where possible.
- Version control and CI for visionOS builds.

This spec provides a complete blueprint for `DummyUiContext`. Implement incrementally, starting with core methods, and test at each step. If issues arise, the visionOS logs will pinpoint problems.