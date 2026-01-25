# OpenRCT2 visionOS - Project Overview

> Quick reference for agents and developers. Full details in [OPENRCT2_VISIONOS_EPIC.md](OPENRCT2_VISIONOS_EPIC.md).

## Project Summary

| Field | Value |
|-------|-------|
| **Goal** | Port OpenRCT2 to visionOS using native SwiftUI + RealityKit |
| **Target** | visionOS 2.0+ (Apple Vision Pro) |
| **Approach** | Bypass SDL; use X8DrawingEngine software renderer + Metal |
| **Effort** | ~105 hours (24 tickets across 6 milestones) |
| **Status** | Planning Complete → Ready for M1 |

## Core Architecture

```
Swift App (SwiftUI + RealityKit)
    ↓
TextureResource.DrawableQueue (90/120 Hz)
    ↓
Metal Compute Shader (palette conversion)
    ↓
VisionOSUiContext (IUiContext implementation)
    ↓
X8DrawingEngine (uint8_t* pixel buffer)
    ↓
OpenRCT2 Game Core (C++)
```

## Key Technical Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| C++ Interop | Swift 5.9+ direct | No C wrapper; `module.modulemap` |
| Display | DrawableQueue | 90 Hz without frame drops |
| Palette | Metal compute shader | 10× faster than CPU |
| Build | CMake + vcpkg | `arm64-xros` triplet |

## Milestone Breakdown

| # | Milestone | Tickets | Hours | Gate |
|---|-----------|---------|-------|------|
| M1 | Xcode Foundation | VOS-001→005 | 15 | C++ lib compiles for visionOS |
| M2 | VisionOSUiContext | VOS-010→014 | 20 | Pixel buffer accessible from Swift |
| M3 | Metal Bridge | VOS-020→023 | 20 | DrawableQueue renders at 90 Hz |
| M4 | RealityKit Display | VOS-030→033 | 15 | Live gameplay in window ≥30fps |
| M5 | Input | VOS-040→044 | 20 | Look+pinch interaction works |
| M6 | Audio | VOS-050→053 | 15 | Music + SFX via AVFoundation |

## Key Files & Interfaces

### C++ (Existing)
- `src/openrct2/drawing/X8DrawingEngine.h` - Software renderer (`_bits`, `_width`, `_height`, `_pitch`)
- `src/openrct2/drawing/ColourPalette.h` - `GamePalette` (BGRA format, 256 colors)
- `src/openrct2/ui/UiContext.h` - `IUiContext` interface to implement
- `src/openrct2-ui/drawing/engines/HardwareDisplayDrawingEngine.cpp:275` - `CopyBitsToTexture()` reference pattern

### Swift (To Create)
- `Sources/OpenRCT2App/OpenRCT2App.swift` - @main entry, WindowGroup
- `Sources/OpenRCT2App/GameEngine.swift` - C++ interop coordinator
- `Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift` - DrawableQueue pipeline
- `Sources/OpenRCT2App/Rendering/Shaders/PaletteConvert.metal` - GPU palette conversion
- `Sources/OpenRCT2Core/visionos/VisionOSUiContext.h` - IUiContext for visionOS

### Build Config (To Create)
- `cmake/visionos-arm64.toolchain.cmake`
- `cmake/visionos-simulator.toolchain.cmake`
- `vcpkg/triplets/community/arm64-xros.cmake`
- `vcpkg/triplets/community/arm64-xros-simulator.cmake`

## Critical Implementation Notes

1. **Palette is BGRA** - Not RGBA. Conversion required in shader.
2. **Pitch is offset** - `RenderTarget.pitch` + `width` = actual stride
3. **DrawableQueue triple-buffers** - Never blocks; call `nextDrawable()` → write → `present()`
4. **Game tick ~40 Hz** - Display runs at 90 Hz independently
5. **No SDL** - All SDL calls must be replaced with native APIs

## Post-MVP Enhancements

| Enhancement | Effort | Description |
|-------------|--------|-------------|
| Parallax UI | +15 hrs | Depth-layered toolbars/dialogs |
| Diorama Mode | +20 hrs | Tilted view like model train set |
| God Mode | +30 hrs | ImmersiveSpace, park on table below user |
| Spatial Audio | +25 hrs | 3D positioned sounds |

## Resources

- [Full Epic Document](OPENRCT2_VISIONOS_EPIC.md)
- [Archived iOS/SDL Docs](docs/archive/ios-sdl-approach/)
- [Swift C++ Interop](https://www.swift.org/documentation/cxx-interop/)
- [visionOS Documentation](https://developer.apple.com/documentation/visionos/)
- [TextureResource.DrawableQueue](https://developer.apple.com/documentation/realitykit/textureresource/drawablequeue)

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
| `mcp_xcodebuildmcp_build_sim` | Build for visionOS Simulator |
| `mcp_xcodebuildmcp_build_run_sim` | Build and run on Simulator |
| `mcp_xcodebuildmcp_launch_app_sim` | Launch already-built app |
| `mcp_xcodebuildmcp_describe_ui` | Get UI hierarchy for input testing |
| `mcp_xcodebuildmcp_gesture` | Simulate gestures (scroll, swipe) |
| `mcp_xcodebuildmcp_type_text` | Type text input |
| `mcp_xcodebuildmcp_scaffold_ios_project` | Create new Xcode project (M1) |
| `mcp_xcodebuildmcp_doctor` | Check build environment |

### Example Workflow

```
1. mcp_xcodebuildmcp_doctor          # Verify environment
2. mcp_xcodebuildmcp_scaffold_ios_project  # Create visionOS project (adapt for visionOS)
3. mcp_xcodebuildmcp_build_sim       # Build for simulator
4. mcp_xcodebuildmcp_build_run_sim   # Build and launch
5. mcp_xcodebuildmcp_describe_ui     # Inspect running UI
6. mcp_xcodebuildmcp_gesture         # Test interactions
```
