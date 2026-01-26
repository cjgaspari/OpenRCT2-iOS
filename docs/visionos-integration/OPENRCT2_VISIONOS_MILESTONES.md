# OpenRCT2 visionOS - Milestone Tickets (Metal Window)

> Detailed ticket breakdown for each milestone. See [Overview](OPENRCT2_VISIONOS_OVERVIEW.md) for summary.

---

## Milestone 1: Xcode Project Foundation
**Total Effort**: 14 hours | **Duration**: 1 week

### VOS-001: Create visionOS Xcode Project
**Effort**: 4 hours

**Description**: Create new visionOS app project (WindowGroup) and baseline scaffolding.

**Tasks**:
- [x] Use `mcp_xcodebuildmcp_scaffold_ios_project` (visionOS) or Xcode template
- [x] Set deployment target to visionOS 2.0
- [x] Add placeholder SwiftUI view
- [x] Verify build/run in Simulator

**Acceptance Criteria**:
- Empty visionOS app launches in Simulator
- No build warnings/errors

**Files Created**:
- OpenRCT2.xcodeproj/
- Sources/OpenRCT2App/OpenRCT2App.swift
- Resources/Info.plist

---

### VOS-002: Configure Swift/C++ Interoperability
**Effort**: 4 hours

**Description**: Ensure Swift 5.9+ C++ interop works with the existing C ABI.

**Tasks**:
- [x] module.modulemap + umbrella header + apinotes
- [x] Enable `-cxx-interoperability-mode=default`
- [x] Smoke test importing a C++ type from Swift

**Acceptance Criteria**:
- Swift can import OpenRCT2Core headers and call a trivial C++ symbol

**Files Created**:
- Sources/OpenRCT2Core/include/module.modulemap
- Sources/OpenRCT2Core/include/OpenRCT2Core.h
- Sources/OpenRCT2Core/include/OpenRCT2Core.apinotes

---

### VOS-003: Setup vcpkg Triplet for visionOS
**Effort**: 3 hours

**Description**: Create vcpkg triplets for device + simulator.

**Tasks**:
- [x] arm64-xros.cmake
- [x] arm64-xros-simulator.cmake
- [x] Test `vcpkg install nlohmann-json --triplet=arm64-xros-simulator`

**Acceptance Criteria**:
- Dependency installs succeed for simulator triplet

---

### VOS-004: Create CMake Toolchain File
**Effort**: 2 hours

**Description**: CMake toolchains for device and simulator builds.

**Tasks**:
- [x] visionos-arm64.toolchain.cmake
- [x] visionos-simulator.toolchain.cmake
- [x] Add `__VISIONOS__` define; disable SDL/OpenGL

**Acceptance Criteria**:
- CMake configure succeeds for simulator

---

### VOS-005: Add visionOS Preprocessor Paths
**Effort**: 1 hour

**Description**: Ensure SDL headers are not pulled when `__VISIONOS__` is set.

**Tasks**:
- [x] Guard SDL includes or add stubs as needed
- [x] Verify libopenrct2 builds for simulator

**Acceptance Criteria**:
- `libopenrct2.a` builds with visionOS toolchain without SDL includes

---

## Milestone 2: VisionOSUiContext Implementation
**Total Effort**: 18 hours | **Duration**: 1.5 weeks

### VOS-010: Create VisionOSUiContext Stub
**Effort**: 5 hours

**Description**: Implement `IUiContext` stub for visionOS.

**Tasks**:
- [x] Create VisionOSUiContext.h/.cpp
- [x] Implement required virtuals (window stubs acceptable)
- [x] Factory: `CreateVisionOSUiContext()` exported to Swift

**Acceptance Criteria**:
- Compiles and links; Swift can instantiate via C ABI

---

### VOS-011: Expose Framebuffer Accessors
**Effort**: 4 hours

**Description**: Expose X8DrawingEngine buffer to Swift.

**Tasks**:
- [x] `GetPixelBuffer()`, `GetBufferWidth()`, `GetBufferHeight()`, `GetBufferPitch()`
- [x] Document that stride = width + pitch (bytesPerRow)

**Acceptance Criteria**:
- Swift can read buffer pointer + dimensions after `Draw()`

---

### VOS-012: Expose Palette Accessor
**Effort**: 3 hours

**Description**: Expose current palette for optional shader swizzle.

**Tasks**:
- [x] `const uint32_t* GetPalette()` or BGRA struct view
- [x] Note BGRA byte order

**Acceptance Criteria**:
- Swift can copy 256-entry palette when needed

---

### VOS-013: Implement ProcessMessages()
**Effort**: 3 hours

**Description**: Advance game tick without SDL loop.

**Tasks**:
- [x] Call into core tick; target ~40 Hz when driven externally
- [x] No SDL references

**Acceptance Criteria**:
- Game state advances on call

---

### VOS-014: Implement Draw()
**Effort**: 3 hours

**Description**: Render into X8DrawingEngine buffer.

**Tasks**:
- [x] Invoke drawing pipeline; populate buffer
- [x] Ensure pitch/stride reported correctly

**Acceptance Criteria**:
- Buffer holds a valid frame after Draw()

---

## Milestone 3: Metal Renderer (CAMetalLayer)
**Total Effort**: 18 hours | **Duration**: 1.5 weeks

### VOS-020: Create MetalLayerView
**Effort**: 5 hours

**Description**: UIView subclass with CAMetalLayer and render loop.

**Tasks**:
- [ ] Override `layerClass` → CAMetalLayer; set pixelFormat BGRA8
- [ ] Own `MTLDevice`/`MTLCommandQueue`
- [ ] Manage `CADisplayLink` tick hook

**Acceptance Criteria**:
- MetalLayerView draws a clear color to the layer without crashing

---

### VOS-021: Build Render Pipeline + Sampler
**Effort**: 5 hours

**Description**: Minimal vertex/fragment pipeline for fullscreen triangle.

**Tasks**:
- [ ] Add Shaders.metal (vertex_main/fragment_main, nearest sampler)
- [ ] Create `MTLRenderPipelineState`
- [ ] Create `MTLSamplerState` (nearest, clamp)
- [ ] Optional fragment swizzle path if C++ cannot emit BGRA

**Acceptance Criteria**:
- Pipeline compiles; triangle renders with a test texture

---

### VOS-022: Texture Management & Upload
**Effort**: 4 hours

**Description**: Manage reusable `MTLTexture` for framebuffer uploads.

**Tasks**:
- [ ] `ensureTexture(width:height:)` recreates on size change only
- [ ] `upload(framePtr:strideBytes:)` using `replaceRegion`
- [ ] Optional double-buffering toggle

**Acceptance Criteria**:
- Upload shows correct colors; no per-frame recreation; stride uses `bytesPerRow = width + pitch` from C ABI

---

### VOS-023: Command Encoding & Present
**Effort**: 4 hours

**Description**: Encode draw pass to CAMetalLayer drawable.

**Tasks**:
- [ ] Create render pass descriptor targeting drawable
- [ ] Bind texture + sampler; draw 3-vertex triangle
- [ ] Present drawable; handle nil drawable gracefully

**Acceptance Criteria**:
- Frame presents without GPU validation errors

---

### VOS-024: Tick Driver Integration
**Effort**: 3 hours

**Description**: Use CAMetalLayer view’s `CADisplayLink` to drive game tick + upload + draw.

**Tasks**:
- [ ] Create display link inside MetalLayerView; call `rct2_update/openrct2_tick`
- [ ] Keep rendering on main; pause when app inactive or drawable nil
- [ ] Ensure no double-ticking if background engine thread remains

**Acceptance Criteria**:
- Single loop drives tick/upload/draw; no duplicate ticks; resumes cleanly after pause

---

## Milestone 4: SwiftUI Host & Resize
**Total Effort**: 12 hours | **Duration**: 1 week

### VOS-030: Replace RealityView with UIViewRepresentable
**Effort**: 4 hours

**Description**: Swap GameView to host MetalLayerView.

**Tasks**:
- [ ] Create UIViewRepresentable wrapper
- [ ] Wire lifecycle to start/stop display link
- [ ] Remove RealityKit/DQ dependencies

**Acceptance Criteria**:
- GameView shows Metal-backed surface in window

---

### VOS-031: Size/Scale Management
**Effort**: 4 hours

**Description**: Handle window size changes and framebuffer resize.

**Tasks**:
- [ ] Observe GeometryReader size changes
- [ ] Compute contained framebuffer size (maintain aspect)
- [ ] Call `openrct2_set_screen_size`; recreate texture on change

**Acceptance Criteria**:
- Resize works without tearing; letterboxing correct

---

### VOS-032: Frame Loop Integration
**Effort**: 4 hours

**Description**: Tie game tick + upload + draw together.

**Tasks**:
- [ ] Decide tick driver (MetalLayerView vs existing engineQueue)
- [ ] Ensure `dt` passed to C++ tick; avoid double-ticking
- [ ] Log-frame pacing for debugging

**Acceptance Criteria**:
- Continuous frames rendered from live game buffer

---

## Milestone 5: Input Bridge (View Coordinates)
**Total Effort**: 16 hours | **Duration**: 1.5 weeks

### VOS-040: Pointer/Gesture Plumbing
**Effort**: 4 hours

**Description**: Add tap/drag/scroll/long-press handlers to MetalLayerView.

**Tasks**:
- [ ] UITapGestureRecognizer → left click
- [ ] UILongPressGestureRecognizer → right click (optional)
- [ ] UIPanGestureRecognizer → drag with left down
- [ ] UIScrollGestureRecognizer/scrollWheel events → wheel

**Acceptance Criteria**:
- Events fire and reach GameEngine/InputBridge

---

### VOS-041: Coordinate Mapping Helper
**Effort**: 4 hours

**Description**: Map UIView points to framebuffer pixels.

**Tasks**:
- [ ] Implement contain-scaling + letterbox offsets
- [ ] Reject events outside render rect
- [ ] Unit-test math with known sizes

**Acceptance Criteria**:
- Click/drag lands on expected UI elements visually

---

### VOS-042: CursorState Updates
**Effort**: 4 hours

**Description**: Feed mapped coordinates into existing C ABI cursor functions.

**Tasks**:
- [ ] Update InputBridge to accept view-space points
- [ ] Ensure thread-safe handoff to C++

**Acceptance Criteria**:
- Game cursor follows gestures correctly

---

### VOS-043: Resilience & Edge Cases
**Effort**: 4 hours

**Description**: Handle focus loss, window move, and display link pause.

**Tasks**:
- [ ] Pause display link when app inactive
- [ ] Reset buttons on cancel/end
- [ ] Clamp coordinates to framebuffer bounds

**Acceptance Criteria**:
- No stuck buttons or runaway cursor after interruptions

---

## Milestone 6: Audio via AVFoundation (Optional)
**Total Effort**: 12 hours | **Duration**: 1 week

### VOS-050: AudioBridge Skeleton
**Effort**: 3 hours

**Description**: Initialize AVAudioEngine and basic playback hooks.

**Tasks**:
- [ ] Start engine; expose volume control
- [ ] Document threading expectations

**Acceptance Criteria**:
- Engine starts without errors; volume adjustable

---

### VOS-051: C++ Audio Adapter
**Effort**: 4 hours

**Description**: Route C++ audio buffers into Swift AudioBridge.

**Tasks**:
- [ ] Implement adapter struct/class in C++
- [ ] Marshal buffers to Swift; manage lifetime

**Acceptance Criteria**:
- C++ audio callbacks reach Swift without leaks

---

### VOS-052: SFX Playback
**Effort**: 3 hours

**Description**: Wire sound effects to AudioBridge.

**Tasks**:
- [ ] Support concurrent sounds
- [ ] Validate with UI click/ride sounds

**Acceptance Criteria**:
- SFX audible without glitches

---

### VOS-053: Music Playback
**Effort**: 2 hours

**Description**: Looping background music.

**Tasks**:
- [ ] Load and loop tracks; independent volume

**Acceptance Criteria**:
- Music loops; independent from SFX volume

---

## Definition of Done (All Milestones)

- [ ] M1: C++ OpenRCT2Core builds for visionOS simulator
- [ ] M2: VisionOSUiContext exposes framebuffer + palette via C ABI
- [ ] M3: CAMetalLayer renderer presents frames with nearest sampling
- [ ] M4: SwiftUI window hosts Metal view and resizes cleanly
- [ ] M5: Click/drag/scroll/right-click work in window coordinates
- [ ] M6: Audio plays (if enabled)
- [ ] No crashes during 15+ minutes gameplay
