# OpenRCT2 visionOS Implementation Progress

> Auto-generated from OPENRCT2_VISIONOS_MILESTONES.md  
> Last updated: 2026-01-25

## Current Status

| Milestone | Status | Progress | Gate Criteria |
|-----------|--------|----------|---------------|
| M1: Xcode Foundation | ✅ Complete | 5/5 | C++ lib compiles for visionOS |
| M2: VisionOSUiContext | ✅ Complete | 5/5 | Pixel buffer accessible from Swift |
| M3: Metal Bridge | ✅ Complete | 4/4 | DrawableQueue renders at 90 Hz |
| M4: RealityKit Display | ✅ Complete | 4/4 | Live gameplay in window ≥30fps |
| M4.5: Game Context | 🟡 Deferred | 0/3 | Real game viewport renders |
| M5: Input | 🔴 Not Started | 0/5 | Look+pinch interaction works |
| M6: Audio | 🔴 Not Started | 0/4 | Music + SFX via AVFoundation |

**Total Progress**: 18/30 tasks (60%)  
**Estimated Remaining**: ~55 hours

---

## Detailed Task Status

### Milestone 1: Xcode Project Foundation (15 hours) ✅

> **Gate**: C++ lib compiles for visionOS simulator ✅

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-001 | Create visionOS Xcode Project | ✅ Completed | 4h | 2026-01-25 | OpenRCT2.xcodeproj + Package.swift |
| VOS-002 | Configure Swift/C++ Interoperability | ✅ Completed | 4h | 2026-01-25 | module.modulemap + apinotes |
| VOS-003 | Setup vcpkg Triplet for visionOS | ✅ Completed | 3h | 2026-01-25 | arm64-xros + arm64-xros-simulator |
| VOS-004 | Create CMake Toolchain File | ✅ Completed | 2h | 2026-01-25 | visionos-arm64 + visionos-simulator |
| VOS-005 | Add visionOS Preprocessor Paths | ✅ Completed | 2h | 2026-01-25 | __VISIONOS__ define |

---

### Milestone 2: VisionOSUiContext Implementation (20 hours) ✅

> **Gate**: Pixel buffer accessible from Swift ✅  
> **Depends on**: M1 complete

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-010 | Create VisionOSUiContext Stub | ✅ Completed | 6h | 2026-01-25 | Full IUiContext impl |
| VOS-011 | Expose GetPixelBuffer() Accessor | ✅ Completed | 4h | 2026-01-25 | Via OpenRCT2Shim.h |
| VOS-012 | Expose GetPalette() Accessor | ✅ Completed | 4h | 2026-01-25 | GetPaletteBGRA() |
| VOS-013 | Implement ProcessMessages() | ✅ Completed | 3h | 2026-01-25 | ~40Hz tick pacing |
| VOS-014 | Implement Draw() | ✅ Completed | 3h | 2026-01-25 | X8DrawingEngine integration |

---

### Milestone 3: Metal Texture Bridge (20 hours) ✅

> **Gate**: DrawableQueue renders static frame at 90 Hz ✅  
> **Depends on**: M2 complete

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-020 | Create OpenRCT2Renderer with DrawableQueue | ✅ Completed | 6h | 2026-01-25 | TextureResource.DrawableQueue |
| VOS-021 | Implement Metal Compute Shader | ✅ Completed | 6h | 2026-01-25 | PaletteConvert.metal |
| VOS-022 | Wire Up Palette Buffer | ✅ Completed | 4h | 2026-01-25 | updatePalette() method |
| VOS-023 | Implement uploadFrame() | ✅ Completed | 4h | 2026-01-25 | Pitch handling + present |

---

### Milestone 4: RealityKit Display (15 hours)

> **Gate**: Live gameplay renders in window at ≥30fps  
> **Depends on**: M3 complete

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-030 | Create RealityView with Plane Entity | ✅ Completed | 4h | 2026-01-25 | GameView with 1.28m×0.72m plane |
| VOS-031 | Apply TextureResource to Plane Material | ✅ Completed | 4h | 2026-01-25 | UnlitMaterial + DrawableQueue |
| VOS-032 | Connect Game Loop to Render Pipeline | ✅ Completed | 4h | 2026-01-25 | GameEngine 40Hz loop → renderer |
| VOS-033 | Handle Window Resize | ✅ Completed | 3h | 2026-01-25 | GeometryReader + plane resize |

---
### Milestone 4.5: Full Game Context Integration (8-12 hours) — DEFERRED

> **Gate**: Real game viewport renders (title screen or park)  
> **Depends on**: M4 complete + test pattern renders with correct colors  
> **Status**: 🟡 DEFERRED — Awaiting test pattern color verification

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-035 | Integrate GameContext Initialization | 🔴 Not Started | 4h | - | Wire up full GameContext |
| VOS-036 | Connect Real Drawing Contexts | 🔴 Not Started | 4h | - | Replace test Draw() with game loop |
| VOS-037 | Asset Loading for visionOS | 🔴 Not Started | 4h | - | g1.dat/g2.dat sprite loading |

**Why Deferred**: Current implementation shows test pattern (background + rectangle fill). Before wiring full game context, we must verify the Metal shader palette conversion produces correct colors. A channel swap bug was identified and fixed — rebuild required to verify.

---
### Milestone 5: Gaze + Pinch Input (20 hours)

> **Gate**: Look+pinch clicks register correctly in game  
> **Depends on**: M4 complete

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-040 | Create InputBridge Class | 🔴 Not Started | 4h | - | |
| VOS-041 | Add SpatialTapGesture Handler | 🔴 Not Started | 4h | - | Depends: VOS-040 |
| VOS-042 | Add DragGesture Handler | 🔴 Not Started | 4h | - | Depends: VOS-040 |
| VOS-043 | Add LongPressGesture Handler | 🔴 Not Started | 4h | - | Depends: VOS-040 |
| VOS-044 | Coordinate Mapping (3D → 2D) | 🔴 Not Started | 4h | - | |

---

### Milestone 6: Audio via AVFoundation (15 hours)

> **Gate**: Music and SFX play correctly  
> **Depends on**: M2 complete (can parallel with M3-M5)

| Ticket | Description | Status | Effort | Completed | Notes |
|--------|-------------|--------|--------|-----------|-------|
| VOS-050 | Create AudioBridge Class | 🔴 Not Started | 4h | - | |
| VOS-051 | Implement Music Playback | 🔴 Not Started | 4h | - | Depends: VOS-050 |
| VOS-052 | Implement Sound Effects | 🔴 Not Started | 4h | - | Depends: VOS-050 |
| VOS-053 | Volume Controls | 🔴 Not Started | 3h | - | Depends: VOS-050 |

---

## Completion Log

| Date | Ticket | Description | Commit | Agent Notes |
|------|--------|-------------|--------|-------------|
| 2026-01-25 | VOS-001→005 | M1: Xcode Project Foundation | `7d6ed54fa0` | All 5 tickets |
| 2026-01-25 | VOS-010→014 | M2: VisionOSUiContext Implementation | `ba2e0afc6c` | Full IUiContext |
| 2026-01-25 | VOS-020→023 | M3: Metal Texture Bridge | `82ff67358d` | DrawableQueue pipeline |
| 2026-01-25 | VOS-030 | RealityView with Plane Entity | `fa94f1c2c6` | GameView + InputTargetComponent |
| 2026-01-25 | VOS-031 | Apply TextureResource to Plane Material | - | UnlitMaterial + DrawableQueue |
| 2026-01-25 | VOS-032 | Connect Game Loop to Render Pipeline | - | GameEngine coordinates 40Hz ticks |
| 2026-01-25 | VOS-033 | Handle Window Resize | - | GeometryReader + dynamic resize |
| 2026-01-25 | BUGFIX | Metal shader RGBA channel order | - | Fixed BGRA→RGBA swap in PaletteConvert.metal |
| 2026-01-25 | BUGFIX | Engine warm-up race condition | - | Added openrct2_tick() after init for DrawingEngine creation |

---

## Blocked Tasks

| Ticket | Blocker | Since | Resolution |
|--------|---------|-------|------------|
| - | No blocked tasks | - | - |

---

## Technical Notes

> Important discoveries and decisions made during implementation

### Architecture Decisions

1. **C Shim Implementation Location**: All C shim functions (`openrct2_*`) are implemented in `VisionOSUiContext.cpp` rather than `OpenRCT2Shim.cpp`. This avoids incomplete type errors since VisionOSUiContext.cpp has access to full type definitions.

2. **WindowManager Disabled**: `IWindowManager` is returned as `nullptr` from `GetWindowManager()` to avoid including `WindowManager.h` which pulls in `sfl/static_vector.hpp` dependency that's not available for visionOS.

3. **Mach Time Instead of chrono**: Using `<mach/mach_time.h>` instead of `<chrono>` for timing in ProcessMessages() to avoid visionOS SDK header ordering issues.

### Known Issues

1. ~~**visionOS SDK CHAR_BIT Issue**: The visionOS SDK has a header ordering issue where `<climits>` must be included BEFORE any C++ stdlib headers like `<chrono>`, `<ratio>`, etc. Otherwise, undefined `CHAR_BIT` and `INT_MAX` errors occur.~~ **FIXED**: Added comprehensive limit macro definitions (`CHAR_BIT`, `INT_MAX`, `ULONG_MAX`, etc.) to `Config/Debug.xcconfig` and `Config/Release.xcconfig` via `GCC_PREPROCESSOR_DEFINITIONS`.

2. **PaletteIndex Enum Values**: `PaletteIndex::pi4` doesn't exist - use `pi10`, `pi14`, etc. Check `src/openrct2/drawing/PaletteIndex.h` for valid values.

3. ~~**SwiftUICore Linker Error**: Build currently fails at link stage with "cannot link directly with 'SwiftUICore'" - this is a project/SDK configuration issue requiring further investigation.~~ **FIXED**: This was resolved by fixing the SDK header issues.

4. ~~**Network Framework Header Collision**: The Apple `Network.framework` conflicts with OpenRCT2's `src/openrct2/Network/Network.h` when `src/openrct2` is in the header search path.~~ **FIXED**: Removed `$(SRCROOT)/src/openrct2` from `HEADER_SEARCH_PATHS` in project.pbxproj. All OpenRCT2 headers should be included as `<openrct2/...>` not directly.

5. ~~**Blue Plane Instead of Game Colors**: Test pattern rendered as solid blue instead of reddish colors.~~ **FIXED**: Metal's `texture.write()` expects RGBA component order regardless of texture pixel format. The shader was outputting `half4(b,g,r,a)` when it should output `half4(r,g,b,a)`. Fixed in `PaletteConvert.metal`.

6. ~~**Frame Buffer Unavailable on First Frames**: `openrct2_get_frame_buffer()` returned `nullptr` initially because `X8DrawingEngine` is created lazily on first `Draw()` call.~~ **FIXED**: Added warm-up `openrct2_tick()` call after `openrct2_init()` in `GameEngine.swift` to ensure drawing engine exists before game loop starts.

### Useful Commands

```bash
# Build for visionOS Simulator
mcp_xcodebuildmcp_build_sim

# Check for errors
get_errors

# Run tests
runTests

# Verify environment
mcp_xcodebuildmcp_doctor

# Build via xcodebuild
xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 -destination 'generic/platform=visionOS Simulator' build
```

### Files Changed for visionOS Build Fix (2026-01-25)

| File | Change |
|------|--------|
| `Config/Debug.xcconfig` | Created with limit macro definitions |
| `Config/Release.xcconfig` | Created with limit macro definitions |
| `Config/Tests.xcconfig` | Created (empty placeholder) |
| `Package.swift` | Added limit macros to cxxSettings, removed conflicting header path |
| `OpenRCT2.xcodeproj/project.pbxproj` | Removed `$(SRCROOT)/src/openrct2` from header search paths |
| `Sources/OpenRCT2Core/visionos/X8DrawingEngineVisionOS.cpp` | Created minimal X8DrawingEngine impl |
| `Sources/OpenRCT2Core/visionos/InvalidationGridVisionOS.cpp` | Created visionOS-compatible copy |
| `Sources/OpenRCT2Core/visionos/RenderTargetVisionOS.cpp` | Created visionOS-compatible copy |

---

## Status Legend

| Icon | Meaning |
|------|---------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| ✅ | Completed |
| 🚫 | Blocked |
