# OpenRCT2 visionOS - Milestone Tickets

> Detailed ticket breakdown for each milestone. See [Overview](OPENRCT2_VISIONOS_OVERVIEW.md) for summary.

---

## Milestone 1: Xcode Project Foundation
**Total Effort**: 15 hours | **Duration**: 1 week

### VOS-001: Create visionOS Xcode Project
**Effort**: 4 hours

**Description**: Create new Xcode project with visionOS app template.

**Tasks**:
- [ ] Use `mcp_xcodebuildmcp_scaffold_ios_project` or Xcode template for visionOS
- [ ] Configure for visionOS 2.0 deployment target
- [ ] Set up basic WindowGroup with placeholder view
- [ ] Verify builds and runs in visionOS Simulator

**Acceptance Criteria**:
- Empty visionOS app launches in Simulator
- No build warnings/errors

**Files Created**:
- `OpenRCT2.xcodeproj/`
- `Sources/OpenRCT2App/OpenRCT2App.swift`
- `Resources/Info.plist`

---

### VOS-002: Configure Swift/C++ Interoperability
**Effort**: 4 hours

**Description**: Set up Swift 5.9+ C++ interop to call OpenRCT2 C++ code directly.

**Tasks**:
- [ ] Create `module.modulemap` for OpenRCT2Core
- [ ] Create umbrella header `OpenRCT2Core.h`
- [ ] Add `.apinotes` for Swift-friendly naming
- [ ] Enable `-cxx-interoperability-mode=default` in build settings
- [ ] Test: import a simple C++ struct in Swift

**Acceptance Criteria**:
- Swift code can `import OpenRCT2Core`
- Can instantiate a C++ struct from Swift

**Files Created**:
- `Sources/OpenRCT2Core/include/module.modulemap`
- `Sources/OpenRCT2Core/include/OpenRCT2Core.h`
- `Sources/OpenRCT2Core/include/OpenRCT2Core.apinotes`

**References**:
- [Swift C++ Interop Docs](https://www.swift.org/documentation/cxx-interop/)

---

### VOS-003: Setup vcpkg Triplet for visionOS
**Effort**: 3 hours

**Description**: Create vcpkg triplet files for building dependencies on visionOS.

**Tasks**:
- [ ] Create `arm64-xros.cmake` triplet (device)
- [ ] Create `arm64-xros-simulator.cmake` triplet (simulator)
- [ ] Test building a simple dependency (e.g., nlohmann-json)
- [ ] Document any port patches needed

**Acceptance Criteria**:
- `vcpkg install nlohmann-json --triplet=arm64-xros-simulator` succeeds

**Files Created**:
- `vcpkg/triplets/community/arm64-xros.cmake`
- `vcpkg/triplets/community/arm64-xros-simulator.cmake`

---

### VOS-004: Create CMake Toolchain File
**Effort**: 2 hours

**Description**: CMake toolchain for cross-compiling to visionOS.

**Tasks**:
- [ ] Create `visionos-arm64.toolchain.cmake` (device)
- [ ] Create `visionos-simulator.toolchain.cmake` (simulator)
- [ ] Add `__VISIONOS__` preprocessor define
- [ ] Disable SDL, Discord, OpenGL in CMake config

**Acceptance Criteria**:
- CMake configures without errors using toolchain
- `__VISIONOS__` defined in compilation

**Files Created**:
- `cmake/visionos-arm64.toolchain.cmake`
- `cmake/visionos-simulator.toolchain.cmake`

---

### VOS-005: Add visionOS Preprocessor Paths
**Effort**: 2 hours

**Description**: Ensure C++ headers resolve without SDL dependencies.

**Tasks**:
- [ ] Add `#ifdef __VISIONOS__` guards where SDL is included
- [ ] Create stub headers if needed for missing platform APIs
- [ ] Verify core library compiles with new toolchain

**Acceptance Criteria**:
- `libopenrct2.a` builds for visionOS simulator
- No SDL header includes when `__VISIONOS__` defined

**Files Modified**:
- Various headers with SDL includes

---

## Milestone 2: VisionOSUiContext Implementation
**Total Effort**: 20 hours | **Duration**: 1.5 weeks

### VOS-010: Create VisionOSUiContext Stub
**Effort**: 6 hours

**Description**: Implement `IUiContext` interface for visionOS platform.

**Tasks**:
- [ ] Create `VisionOSUiContext.h` header
- [ ] Create `VisionOSUiContext.cpp` implementation
- [ ] Implement all pure virtual methods (stubs OK initially)
- [ ] Add factory function `CreateVisionOSUiContext()`
- [ ] Register in build system

**Acceptance Criteria**:
- Compiles and links
- Can instantiate from Swift via interop

**Files Created**:
- `Sources/OpenRCT2Core/visionos/VisionOSUiContext.h`
- `Sources/OpenRCT2Core/visionos/VisionOSUiContext.cpp`

**Key Interface** (from `UiContext.h`):
```cpp
virtual void CreateWindow() = 0;
virtual CursorState GetCursorState() = 0;
virtual void ProcessMessages() = 0;
virtual void Draw() = 0;
```

---

### VOS-011: Expose GetPixelBuffer() Accessor
**Effort**: 4 hours

**Description**: Allow Swift to access X8DrawingEngine's pixel buffer.

**Tasks**:
- [ ] Add `uint8_t* GetPixelBuffer()` method
- [ ] Add `uint32_t GetBufferWidth()` method
- [ ] Add `uint32_t GetBufferHeight()` method
- [ ] Add `int32_t GetBufferPitch()` method
- [ ] Ensure thread-safe access pattern documented

**Acceptance Criteria**:
- Swift can read pixel buffer pointer after `Draw()` call
- Buffer dimensions accessible

---

### VOS-012: Expose GetPalette() Accessor
**Effort**: 4 hours

**Description**: Allow Swift to access current game palette for color conversion.

**Tasks**:
- [ ] Add `const uint32_t* GetPalette()` method returning hardware-mapped palette
- [ ] Or expose `GamePalette` directly with BGRA struct
- [ ] Document BGRA byte order

**Acceptance Criteria**:
- Swift can read 256-entry palette
- Palette updates when game changes it (day/night, etc.)

**Note**: Palette is BGRA format, not RGBA!

---

### VOS-013: Implement ProcessMessages()
**Effort**: 3 hours

**Description**: Game tick processing without SDL event loop.

**Tasks**:
- [ ] Implement `ProcessMessages()` to run game logic tick
- [ ] Handle timing (target ~40 Hz game tick)
- [ ] Integrate with Swift game loop caller

**Acceptance Criteria**:
- Game state advances when called
- No SDL dependencies

---

### VOS-014: Implement Draw()
**Effort**: 3 hours

**Description**: Trigger X8DrawingEngine render cycle.

**Tasks**:
- [ ] Implement `Draw()` to call engine's render methods
- [ ] Ensure pixel buffer populated after call
- [ ] Handle dirty rect optimization if applicable

**Acceptance Criteria**:
- Pixel buffer contains valid frame data after `Draw()`
- Can render static scene (title screen or loaded park)

---

## Milestone 3: Metal Texture Bridge (DrawableQueue)
**Total Effort**: 20 hours | **Duration**: 1.5 weeks

### VOS-020: Create OpenRCT2Renderer with DrawableQueue
**Effort**: 6 hours

**Description**: Swift class managing Metal texture pipeline via RealityKit's DrawableQueue.

**Tasks**:
- [ ] Create `OpenRCT2Renderer.swift`
- [ ] Initialize `MTLDevice` and `MTLCommandQueue`
- [ ] Create `TextureResource.DrawableQueue` at game resolution
- [ ] Create `TextureResource` from DrawableQueue
- [ ] Implement `resize(width:height:)` for resolution changes

**Acceptance Criteria**:
- DrawableQueue created at 1280×720
- TextureResource accessible for RealityKit material

**Files Created**:
- `Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift`

---

### VOS-021: Implement Metal Compute Shader
**Effort**: 6 hours

**Description**: GPU shader for indexed-to-RGBA palette conversion.

**Tasks**:
- [ ] Create `PaletteConvert.metal` shader file
- [ ] Implement `convertIndexedToRGBA` kernel
- [ ] Handle BGRA→RGBA channel reordering
- [ ] Create `MTLComputePipelineState` in renderer
- [ ] Allocate palette buffer (256 × 4 bytes)

**Acceptance Criteria**:
- Shader compiles
- Pipeline state created successfully

**Files Created**:
- `Sources/OpenRCT2App/Rendering/Shaders/PaletteConvert.metal`

**Shader Signature**:
```metal
kernel void convertIndexedToRGBA(
    device const uchar* indexedBuffer [[buffer(0)]],
    device const PaletteEntry* palette [[buffer(1)]],
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
)
```

---

### VOS-022: Wire Up Palette Buffer
**Effort**: 4 hours

**Description**: Copy palette from C++ to Metal buffer.

**Tasks**:
- [ ] Implement `updatePalette(_ palette:count:)` in renderer
- [ ] Create shared `MTLBuffer` for palette
- [ ] Call update when palette changes (observe from C++)
- [ ] Verify BGRA byte order preserved

**Acceptance Criteria**:
- Palette buffer updated from game
- Color output correct (no channel swaps)

---

### VOS-023: Implement uploadFrame()
**Effort**: 4 hours

**Description**: Full frame upload pipeline using DrawableQueue.

**Tasks**:
- [ ] Copy indexed pixels to GPU buffer (handle pitch/stride)
- [ ] Call `nextDrawable()` on queue
- [ ] Dispatch compute shader
- [ ] Call `drawable.present()`
- [ ] Profile for 90 Hz capability

**Acceptance Criteria**:
- Static test image renders correctly
- No frame drops at 90 Hz refresh

**Pattern Reference**: See `CopyBitsToTexture()` in `HardwareDisplayDrawingEngine.cpp:275`

---

## Milestone 4: RealityKit Display
**Total Effort**: 15 hours | **Duration**: 1 week

### VOS-030: Create RealityView with Plane Entity
**Effort**: 4 hours

**Description**: Display surface for game texture in visionOS window.

**Tasks**:
- [ ] Create `GameView.swift` with RealityView
- [ ] Generate plane mesh (1.28m × 0.72m for 16:9)
- [ ] Create ModelEntity with plane
- [ ] Add entity to RealityView content

**Acceptance Criteria**:
- Plane visible in visionOS window
- Correctly sized/positioned

**Files Created**:
- `Sources/OpenRCT2App/Views/GameView.swift`

---

### VOS-031: Apply TextureResource to Plane Material
**Effort**: 4 hours

**Description**: Connect renderer's texture to plane display.

**Tasks**:
- [ ] Create UnlitMaterial with TextureResource
- [ ] Apply material to plane entity
- [ ] Handle texture updates in RealityView `update` closure

**Acceptance Criteria**:
- Static texture displays on plane
- Texture fills plane correctly (no stretching)

---

### VOS-032: Connect Game Loop to Render Pipeline
**Effort**: 4 hours

**Description**: Full integration of game tick → render → display.

**Tasks**:
- [ ] Create `GameEngine.swift` coordinator class
- [ ] Start game loop on background thread
- [ ] Call `ProcessMessages()` → `Draw()` → `uploadFrame()`
- [ ] Synchronize with RealityView updates

**Acceptance Criteria**:
- Live gameplay renders in window
- Achieves ≥30fps game tick

**Files Created**:
- `Sources/OpenRCT2App/GameEngine.swift`

---

### VOS-033: Handle Window Resize
**Effort**: 3 hours

**Description**: Adapt game resolution when window resized.

**Tasks**:
- [ ] Observe window size changes
- [ ] Notify VisionOSUiContext of new dimensions
- [ ] Recreate DrawableQueue if needed
- [ ] Update plane entity size

**Acceptance Criteria**:
- Game adapts to window resize
- No crashes or visual glitches

---

---

## Milestone 4.5: Full Game Context Integration (DEFERRED)
**Total Effort**: 8-12 hours | **Duration**: 0.5 weeks  
**Status**: DEFERRED until test pattern renders correctly

> **Prerequisite**: Test pattern (background + rectangle) must render with correct colors in M4.
> **Goal**: Replace test pattern with actual game viewport rendering.

### VOS-035: Integrate GameContext Initialization
**Effort**: 4 hours

**Description**: Wire up full OpenRCT2 GameContext instead of minimal VisionOSUiContext test stubs.

**Tasks**:
- [ ] Load and initialize full GameContext in `openrct2_init()`
- [ ] Set up title sequence or load a test park file
- [ ] Configure viewport and window system
- [ ] Connect game state machine (intro → title → game)

**Acceptance Criteria**:
- Title screen or loaded park renders in visionOS window
- Game state progresses past initialization

**Dependencies**:
- VOS-033 complete (window resize working)
- Test pattern renders with correct colors

---

### VOS-036: Connect Real Drawing Contexts
**Effort**: 4 hours

**Description**: Replace test Draw() with actual game drawing calls.

**Tasks**:
- [ ] Remove test pattern from `VisionOSUiContext::Draw()`
- [ ] Connect to `DrawingContext` from main game loop
- [ ] Handle viewport invalidation and dirty rects
- [ ] Wire up window manager for UI elements

**Acceptance Criteria**:
- Game windows (toolbar, status bar) render
- Park terrain and objects visible

**Files Modified**:
- `Sources/OpenRCT2Core/visionos/VisionOSUiContext.cpp`
- `Sources/OpenRCT2App/GameEngine.swift`

---

### VOS-037: Asset Loading for visionOS
**Effort**: 4 hours

**Description**: Ensure game assets (sprites, objects) load correctly on visionOS.

**Tasks**:
- [ ] Configure asset paths for app bundle
- [ ] Verify sprite loading from g1.dat/g2.dat
- [ ] Test object loading (rides, scenery)
- [ ] Handle any endianness or format issues

**Acceptance Criteria**:
- Park renders with all objects visible
- No missing sprites or placeholder textures

---

## Milestone 5: Gaze + Pinch Input
**Total Effort**: 20 hours | **Duration**: 1.5 weeks

### VOS-040: Create InputBridge Class
**Effort**: 4 hours

**Description**: Swift class tracking input state for C++ consumption.

**Tasks**:
- [ ] Create `InputBridge.swift`
- [ ] Track cursor position (x, y)
- [ ] Track button states (left, right)
- [ ] Implement `getCursorState()` for C++ polling

**Acceptance Criteria**:
- Input state readable from C++
- Thread-safe access

**Files Created**:
- `Sources/OpenRCT2App/Input/InputBridge.swift`

---

### VOS-041: Add SpatialTapGesture Handler
**Effort**: 4 hours

**Description**: Map visionOS tap (look + pinch) to left click.

**Tasks**:
- [ ] Add `SpatialTapGesture` to GameView
- [ ] Convert 3D tap location to game pixel coordinates
- [ ] Update InputBridge with tap position
- [ ] Trigger left click down/up sequence

**Acceptance Criteria**:
- Tap on game window registers as click
- Correct position in game coordinates

---

### VOS-042: Add DragGesture Handler
**Effort**: 4 hours

**Description**: Map drag to cursor movement with button held.

**Tasks**:
- [ ] Add `DragGesture` to GameView
- [ ] Track drag start/move/end
- [ ] Update cursor position continuously during drag
- [ ] Set left button down during drag

**Acceptance Criteria**:
- Can drag to select areas
- Can drag scrollbars and sliders

---

### VOS-043: Add LongPressGesture Handler
**Effort**: 4 hours

**Description**: Map long press to right click for context menus.

**Tasks**:
- [ ] Add `LongPressGesture` to GameView
- [ ] Trigger right click on long press completion
- [ ] Show visual feedback during press
- [ ] Release right button after brief delay

**Acceptance Criteria**:
- Long press opens context menus
- Can access right-click functionality

---

### VOS-044: Coordinate Mapping (3D → 2D)
**Effort**: 4 hours

**Description**: Accurate conversion from RealityKit 3D coordinates to game pixels.

**Tasks**:
- [ ] Implement `convertToGameCoordinates(_ location3D:)`
- [ ] Account for plane position and rotation
- [ ] Handle edge cases (taps outside game area)
- [ ] Test accuracy across different window sizes

**Acceptance Criteria**:
- Click position matches visual target
- Works at different window sizes

**Formula**:
```swift
// Plane is 1.28m × 0.72m, game is 1280×720 pixels
let x = (location3D.x + 0.64) / 1.28 * CGFloat(gameWidth)
let y = (0.36 - location3D.y) / 0.72 * CGFloat(gameHeight)
```

---

## Milestone 6: Audio via AVFoundation
**Total Effort**: 15 hours | **Duration**: 1 week

### VOS-050: Create AudioBridge with AVAudioEngine
**Effort**: 4 hours

**Description**: Swift audio system using AVFoundation.

**Tasks**:
- [ ] Create `AudioBridge.swift`
- [ ] Initialize `AVAudioEngine`
- [ ] Start audio engine
- [ ] Implement volume control

**Acceptance Criteria**:
- Audio engine starts without errors
- Volume adjustable

**Files Created**:
- `Sources/OpenRCT2App/Audio/AudioBridge.swift`

---

### VOS-051: Implement IAudioContext Adapter
**Effort**: 5 hours

**Description**: Bridge C++ audio calls to Swift AVFoundation.

**Tasks**:
- [ ] Create C++ adapter implementing audio interface
- [ ] Route audio buffer requests to Swift
- [ ] Handle sample format conversion if needed
- [ ] Manage audio source lifecycle

**Acceptance Criteria**:
- C++ audio calls reach Swift
- Audio buffers played correctly

---

### VOS-052: Wire Up SFX Playback
**Effort**: 3 hours

**Description**: Game sound effects through audio bridge.

**Tasks**:
- [ ] Connect ride sounds, UI clicks, etc.
- [ ] Handle multiple simultaneous sounds
- [ ] Test various SFX triggers

**Acceptance Criteria**:
- Sound effects play on game events
- No audio glitches or delays

---

### VOS-053: Wire Up Music Playback
**Effort**: 3 hours

**Description**: Background music through audio bridge.

**Tasks**:
- [ ] Connect music system
- [ ] Implement music looping
- [ ] Handle music track changes
- [ ] Volume independent from SFX

**Acceptance Criteria**:
- Music plays and loops
- Music/SFX volume separate

---

## Definition of Done (All Milestones)

- [ ] **M1**: C++ OpenRCT2Core compiles for visionOS simulator
- [ ] **M2**: VisionOSUiContext implements IUiContext, pixel buffer accessible
- [ ] **M3**: DrawableQueue renders static test frame at 90 Hz
- [ ] **M4**: Live gameplay renders in window at ≥30fps
- [ ] **M5**: Can navigate UI, select tools, place objects via look+pinch
- [ ] **M6**: Audio plays (music + sound effects)
- [ ] No crashes during 15+ minutes gameplay
