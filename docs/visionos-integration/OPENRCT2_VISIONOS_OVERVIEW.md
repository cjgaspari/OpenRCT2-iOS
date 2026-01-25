# OpenRCT2 visionOS - Project Overview

> Quick reference for agents and developers. Full details in [OPENRCT2_VISIONOS_EPIC.md](OPENRCT2_VISIONOS_EPIC.md).

## Project Summary

| Field | Value |
|-------|-------|
| **Goal** | Port OpenRCT2 to visionOS using a SwiftUI window backed by CAMetalLayer |
| **Target** | visionOS 2.0+ (Apple Vision Pro) |
| **Approach** | Bypass SDL; render the X8DrawingEngine buffer into a Metal texture and draw a fullscreen triangle with a nearest sampler |
| **Effort** | ~90-100 hours (updated for Metal window plan) |
| **Status** | RealityKit plan superseded → Metal window migration active |

## Core Architecture

```
Swift App (SwiftUI WindowGroup)
    ↓
GameView (UIViewRepresentable)
    ↓
MetalLayerView (UIView + CAMetalLayer + MTLCommandQueue)
    ↓
rct2_update() / rct2_get_frame() from C++ bridge
    ↓
MTLTexture.replaceRegion (BGRA8) → fullscreen triangle
    ↓
Nearest sampler → CAMetalLayer drawable
```

## Key Technical Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| C++ Interop | Existing C ABI (`openrct2_*`) with Swift 5.9+ | Already live; keeps bridge stable |
| Display | CAMetalLayer + render pipeline | Fewer moving parts than RealityKit DrawableQueue; deterministic pacing |
| Sampling | Nearest sampler in fragment shader | Pixel-perfect UI; no unintended filtering |
| Pixel Format | Prefer BGRA8 from engine (agreed) | Matches Metal default, avoids shader swizzle; fallback swizzle in fragment only if needed |
| Stride Contract | `bytesPerRow = width + pitch` from C ABI (agreed) | Avoids artifacts; single source of truth from C++ |
| Tick Driver | CADisplayLink inside Metal view calls `rct2_update`/`openrct2_tick` (agreed) | Single loop, predictable pacing; upload/draw on main |
| Build | CMake + vcpkg | Reuse current triplets/toolchains |

## Milestone Breakdown (Metal Window)

| # | Milestone | Tickets | Hours | Gate |
|---|-----------|---------|-------|------|
| M1 | Xcode/Foundation | VOS-001→005 | 14 | C++ lib + Swift interop build for visionOS |
| M2 | VisionOSUiContext | VOS-010→014 | 18 | Pixel buffer + palette exposed via C ABI |
| M3 | Metal Renderer | VOS-020→024 | 18 | CAMetalLayer renderer presents frame |
| M4 | SwiftUI Host | VOS-030→033 | 12 | GameView uses Metal view, handles resize |
| M5 | Input Bridge | VOS-040→044 | 16 | Pointer/gesture → CursorState mapping in view coords |
| M6 | Audio (Optional) | VOS-050→053 | 12 | AVFoundation bridge kept but deprioritized |

## Key Files & Interfaces

### C++ (Existing)
- src/openrct2/drawing/X8DrawingEngine.h — software renderer (`_bits`, `_width`, `_height`, `_pitch`)
- src/openrct2/drawing/ColourPalette.h — `GamePalette` (BGRA, 256 colors)
- src/openrct2/ui/UiContext.h — `IUiContext` implemented by visionOS layer

### Swift (To Update/Create)
- Sources/OpenRCT2App/GameView.swift — replace RealityView with UIViewRepresentable wrapper around MetalLayerView
- Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift — retarget from DrawableQueue/compute to CAMetalLayer pipeline
- Sources/OpenRCT2App/GameEngine.swift — reuse C bridge; update frame upload and resize handshake
- Sources/OpenRCT2App/Rendering/Shaders/Shaders.metal — fullscreen triangle + nearest sampler (no compute)
- Sources/OpenRCT2App/Rendering/MetalLayerView.swift — UIView subclass exposing CAMetalLayer draw loop (new)

### Build Config (Reused)
- cmake/visionos-*.toolchain.cmake
- vcpkg/triplets/community/arm64-xros*.cmake

## Critical Implementation Notes

1. **Prefer BGRA output from C++** — avoid per-frame channel swizzle; otherwise swizzle in fragment shader.
2. **Stride awareness** — use `bytesPerRow = strideBytes` from the bridge when calling `replaceRegion`.
3. **Do not recreate textures every frame** — recreate only on size change.
4. **Use nearest sampling** — sampler state `filter::nearest` for crisp UI.
5. **Input uses view coordinates** — map UIView points → framebuffer pixels with letterbox math.

## Post-MVP Enhancements (Optional)

| Enhancement | Effort | Description |
|-------------|--------|-------------|
| Double-buffer uploads | +6 hrs | Rotate 2–3 textures to reduce stalls |
| Compute blit path | +8 hrs | Optionally use MTLBuffer + blit for larger frames |
| RealityKit presentation | +12 hrs | Reintroduce as feature after Metal window is stable |

## Resources

- [Full Epic Document](OPENRCT2_VISIONOS_EPIC.md)
- [Metal migration spec](SPEC_Migrate_RealityKit_to_Metal_Window.md)
- [Metal-cpp notes](metal-cpp-notes.md)
- [Swift C++ Interop](https://www.swift.org/documentation/cxx-interop/)
- [visionOS Documentation](https://developer.apple.com/documentation/visionos/)

## Quick Commands

```bash
# Build for visionOS Simulator
SIMULATOR=1 ./build-visionos.sh

# Build for device
./build-visionos.sh

# Install vcpkg dependencies
./vcpkg/vcpkg install --triplet=arm64-xros-simulator icu libpng libzip speexdsp nlohmann-json
```

## XcodeBuildMCP Tools

Use these MCP tools for building and running:

| Tool | Purpose |
|------|---------|
| mcp_xcodebuildmcp_build_sim | Build for visionOS Simulator |
| mcp_xcodebuildmcp_build_run_sim | Build and run on Simulator |
| mcp_xcodebuildmcp_launch_app_sim | Launch already-built app |
| mcp_xcodebuildmcp_describe_ui | Get UI hierarchy for input testing |
| mcp_xcodebuildmcp_gesture | Simulate gestures (scroll, swipe) |
| mcp_xcodebuildmcp_type_text | Type text input |
| mcp_xcodebuildmcp_scaffold_ios_project | Create new Xcode project (M1) |
| mcp_xcodebuildmcp_doctor | Check build environment |

### Example Workflow

```
1. mcp_xcodebuildmcp_doctor
2. mcp_xcodebuildmcp_scaffold_ios_project (visionOS template)
3. mcp_xcodebuildmcp_build_sim
4. mcp_xcodebuildmcp_build_run_sim
5. mcp_xcodebuildmcp_describe_ui
6. mcp_xcodebuildmcp_gesture
```
