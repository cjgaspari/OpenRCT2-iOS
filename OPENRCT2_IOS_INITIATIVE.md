# OpenRCT2 iOS Initiative: Detailed Technical Specification

**Status**: Planning Phase  
**Target**: Proof-of-Concept (PoC) MVP → Full iOS Support  
**Date Started**: January 24, 2026

---

## Executive Summary

This document outlines the technical roadmap to bring OpenRCT2 to iOS using Swift's improved C interoperability features (as detailed in the [Swift Blog: Improving Usability of C Libraries](https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/)).

**Key Finding**: **SDL→Metal conversion is NOT an absolute requirement for the MVP.** OpenRCT2 uses software rendering into a CPU buffer (`SoftwareWithHardwareDisplay` mode), which can be displayed via standard SDL mechanisms. Metal optimization is a Phase 2+ optimization.

---

## Architecture Analysis

### Current Rendering Pipeline

OpenRCT2 has a well-abstracted rendering architecture:

```
Game Loop (Context.cpp)
    ↓
    Draw() 
        ↓
        DrawingEngine::BeginDraw()
        ↓
        Painter::Paint()
            ├→ de.PaintWindows()  // Software rendering into buffer
            ├→ _uiContext.Draw()  // UI rendering
            └→ de.PaintWeather()
        ↓
        DrawingEngine::EndDraw()
```

### Key Components

| Component | Location | Purpose | Notes |
|-----------|----------|---------|-------|
| **DrawingEngine** | `src/openrct2/drawing/IDrawingEngine.h` | Abstract rendering interface | Two modes: `SoftwareWithHardwareDisplay`, `OpenGL` (experimental) |
| **X8DrawingEngine** | `src/openrct2/drawing/X8DrawingEngine.cpp` | Software rasterizer | CPU-based pixel manipulation into `uint8_t* _bits` buffer |
| **UiContext** | `src/openrct2-ui/UiContext.cpp` | SDL window management | Uses `SDL_CreateWindow()`, handles input/display |
| **Painter** | `src/openrct2/paint/Painter.cpp` | High-level render orchestration | Calls into drawing engine |

### Rendering Mode Details

**SoftwareWithHardwareDisplay (DEFAULT)**
- All rendering done on CPU into a software buffer (`uint8_t _bits[]`)
- Palettized 8-bit colorspace (legacy RCT2 format)
- Supports dirty rectangle optimization
- Platform-specific code updates the SDL surface/texture

**OpenGL (Experimental)**
- Modern GPU-accelerated rendering
- Not required for MVP
- Has limitations (some UI features unsupported)

---

## SDL Support on iOS Analysis

### Current SDL2 iOS Capabilities

✅ **Supported on iOS:**
- Window creation (`SDL_CreateWindow()`)
- Touch input (`SDL_FINGERDOWN`, `SDL_FINGERUP`)
- Rendering backends:
  - **OpenGL ES** (via `SDL_WINDOW_OPENGL` flag) - DEPRECATED but functional
  - **Metal** (via native SDL Metal renderer) - RECOMMENDED for modern iOS
  - **Software rendering** to SDL surface - FUNCTIONAL

### SDL→Metal Requirement: FINAL DETERMINATION

**Answer: Metal is NOT required for MVP, but strongly recommended for production.**

| Scenario | Metal Required? | Rationale |
|----------|-----------------|-----------|
| **MVP/PoC** | ❌ No | SDL2 can update a software surface at ~60 FPS on modern iOS devices (A12+). OpenGL ES may work but deprecated. Software rendering to SDL surface is simplest. |
| **Playable/Usable** | ⚠️ Recommended | SDL's software-to-Metal path will be faster & more battery-efficient. Metal is first-class iOS citizen. Need profiling to determine if software rendering is fast enough at 60 FPS. |
| **Production/Full** | ✅ Yes | For optimal performance, battery life, and OS integration. But not for proving concept works. |

**Why NOT required for MVP:**
1. X8DrawingEngine already does all rendering on CPU
2. We just need to get that buffer to the iOS display
3. SDL2 has built-in mechanisms for this (surface update)
4. Can prove concept works before optimizing rendering path

**Why recommended for later:**
1. Software rendering @ 1024x768 (game typical res) with dirty rects ~60 FPS is borderline on iPhone
2. Metal gives GPU acceleration and power efficiency
3. iOS best practices favor Metal over deprecated OpenGL ES

---

## Detailed Milestone Breakdown

### PHASE 1: Proof-of-Concept (2-3 weeks)

**Goal**: Get a basic iOS app that initializes OpenRCT2 and renders something to screen (even if just a static image).

#### Milestone 1.1: Swift Package Setup

```
OpenRCT2-iOS/
├── Package.swift
├── Sources/
│   ├── OpenRCT2Core/
│   │   ├── include/
│   │   │   ├── module.modulemap        # Clang module definition
│   │   │   ├── OpenRCT2.apinotes       # API notes for C → Swift mapping
│   │   │   └── OpenRCT2Shim.h          # Minimal C header with key exports
│   │   ├── OpenRCT2Shim.c              # C wrapper/shim layer
│   │   └── module.modulemap
│   │
│   └── OpenRCT2App/
│       ├── GameViewController.swift
│       ├── ContentView.swift
│       └── GameRenderer.swift
│
├── Resources/
│   └── [RCT2 data files - if available]
│
└── Tests/
    └── OpenRCT2CoreTests/
```

**Tasks:**
- [ ] **1.1.1**: Create SPM package structure
- [ ] **1.1.2**: Write `module.modulemap` for OpenRCT2 core headers
- [ ] **1.1.3**: Create `OpenRCT2.apinotes` file for key C types (enums, opaque pointers)
- [ ] **1.1.4**: Build C shim layer exposing minimal API:
  - `struct OpenRCT2Instance { void* _context; void* _uiContext; }`
  - `OpenRCT2Instance* OpenRCT2Create()`
  - `void OpenRCT2_Initialize(OpenRCT2Instance*)`
  - `void OpenRCT2_RunFrame(OpenRCT2Instance*)`
  - `uint8_t* OpenRCT2_GetFrameBuffer(OpenRCT2Instance*)`
  - `void OpenRCT2_Destroy(OpenRCT2Instance*)`
- [ ] **1.1.5**: Ensure SPM can build against OpenRCT2 C++ core (CMake integration or pre-built library)

**Deliverable**: Compiling Swift package that can import OpenRCT2 definitions.

---

#### Milestone 1.2: iOS App Shell

**Tasks:**
- [ ] **1.2.1**: Create minimal SwiftUI app with `GameViewController`
- [ ] **1.2.2**: Add Metal view or OpenGL context holder
- [ ] **1.2.3**: Create game loop timer (60 FPS with `CADisplayLink` or `Timer`)
- [ ] **1.2.4**: Implement `GameRenderer` that:
  - Calls `OpenRCT2_RunFrame()`
  - Gets frame buffer pointer
  - Uploads to Metal texture OR directly blits to view

**Deliverable**: iOS app that launches without crashing, shows black screen with proper 60 FPS loop.

---

#### Milestone 1.3: Initialize OpenRCT2 Core

**Tasks:**
- [ ] **1.3.1**: Port minimal `UiContext` for iOS (headless mode acceptable for PoC)
- [ ] **1.3.2**: Call `Context::Initialise()` from Swift
- [ ] **1.3.3**: Load minimal game state (title screen or empty park)
- [ ] **1.3.4**: Set up SDL to render to iOS surface
  - Use `SDL_CreateWindow()` with dummy native window
  - Or use purely headless rendering to buffer

**Key Code Path**: [Context::Initialise()](src/openrct2/Context.cpp#L501)

**Deliverable**: OpenRCT2 initializes, runs tick loop, produces frame buffer output.

---

#### Milestone 1.4: Display Output

**Tasks:**
- [ ] **1.4.1**: Map software frame buffer (paletted 8-bit) to RGBA
- [ ] **1.4.2**: Upload to Metal texture (or SDL surface)
- [ ] **1.4.3**: Render textured quad to screen
- [ ] **1.4.4**: Verify 60 FPS display (may be software-limited)

**Performance Benchmark**:
- Target resolution: 1024×768
- Software rendering: CPU bound, ~50-100 MB/s memory bandwidth per frame @ 60 FPS
- On Apple A14+: expect smooth 60 FPS with dirty rectangle optimization

**Deliverable**: OpenRCT2 park visible on iOS screen, even if just a title screen or loading screen.

---

### PHASE 2: Input & Interaction (2 weeks)

**Goal**: Get touch input working so the park is navigable.

#### Milestone 2.1: Touch Input Mapping

**Tasks:**
- [ ] **2.1.1**: Map iOS touch events to OpenRCT2 input system
  - Single finger tap → mouse left click
  - Two-finger tap → mouse right click
  - Single finger drag → mouse move + left button held
  - Two-finger pinch → zoom (if supported)
  
**Reference**: [UiContext input handling](src/openrct2-ui/UiContext.cpp#L500)

- [ ] **2.1.2**: Handle SDL_FINGERDOWN, SDL_FINGERUP, SDL_FINGERMOTION
- [ ] **2.1.3**: Convert normalized touch coordinates (0-1) to game coordinates

**Deliverable**: Can tap on buttons, drag viewport around.

---

#### Milestone 2.2: Keyboard Input (Optional for MVP)

**Tasks:**
- [ ] **2.2.1**: iOS software keyboard bring-up (for text input, cheats)
- [ ] **2.2.2**: Map hardware keyboard if available

**Note**: Low priority; many park management tasks work with mouse only.

**Deliverable**: Text input in dialog boxes works.

---

### PHASE 3: Asset Loading & Persistence (2 weeks)

**Goal**: Load actual RCT2 data files; save/load parks.

#### Milestone 3.1: Asset Bundle Integration

**Tasks:**
- [ ] **3.1.1**: Package RCT2 data files into app bundle or on-device storage
  - `Data/` directory: sprites, landscapes, objects
  - Language files, sound/music (optional for initial)
  
- [ ] **3.1.2**: Modify file path resolution for iOS sandbox
  - Use `Documents/` or `Application Support/` directories
  - Handle app data bundling

**Reference**: [Android asset copying pattern](src/openrct2-android/app/src/main/java/io/openrct2/MainActivity.java#L146)

**Deliverable**: Game loads actual park graphics; not just placeholder grids.

---

#### Milestone 3.2: Save/Load Functionality

**Tasks:**
- [ ] **3.2.1**: Test save game creation in iOS file system
- [ ] **3.2.2**: Handle file permissions (iOS sandbox restrictions)
- [ ] **3.2.3**: Implement load dialog

**Deliverable**: Can create, save, and load a park on device.

---

### PHASE 4: Optimization & Performance (3 weeks)

**Goal**: Achieve smooth gameplay on target devices; add Metal rendering path.

#### Milestone 4.1: Profiling

**Tasks:**
- [ ] **4.1.1**: Measure CPU & GPU time per frame
  - Use Xcode Instruments (Time Profiler, Metal Debugger)
  - Identify bottlenecks (likely: dirty rectangle updates, palette mapping)
  
- [ ] **4.1.2**: Profile memory usage
  - Typical: 200-400 MB for loaded park
  - iOS device minimum: iPhone 12+, iPad 6th gen+
  
- [ ] **4.1.3**: Thermal & battery impact testing

**Target Performance**:
- iPhone 12+ (A14+): 60 FPS @ 1024×768 (native resolution)
- iPad: 120 FPS possible on newer models

**Deliverable**: Performance profile report.

---

#### Milestone 4.2: Metal Rendering Path

**Tasks:**

Only if 4.1 profiling shows software rendering is insufficient.

- [ ] **4.2.1**: Create Metal rendering backend
  - Abstract layer in `IDrawingEngine` (already exists)
  - New `MetalDrawingEngine` class
  - Or update `SoftwareWithHardwareDisplay` to use Metal for upload
  
- [ ] **4.2.2**: CPU→GPU transfer optimization
  - Use Metal textures instead of pixel-by-pixel copies
  - Implement dirty rectangle → Metal blit pipeline
  - Possible: partial texture updates via MTLBlitCommandEncoder
  
- [ ] **4.2.3**: Palette conversion on GPU (optional advanced)
  - Compute shader for 8-bit → RGBA conversion
  - Would eliminate CPU bottleneck

**Deliverable**: Optional Metal-accelerated rendering path available; switchable via config.

---

#### Milestone 4.3: UI Scaling

**Tasks:**
- [ ] **4.3.1**: Handle super-Retina displays (2x, 3x scale factor)
  - Game renders @ 1024×768, scaled to device resolution
  - Use `UIScreen.main.scale` for proper dimensions
  
- [ ] **4.3.2**: Landscape vs. Portrait orientation
  - Lock to landscape initially; allow portrait as enhancement

**Deliverable**: Game adapts to device size and screen density.

---

### PHASE 5: Polish & Submission (2 weeks)

**Goal**: App Store ready.

#### Milestone 5.1: App Metadata

**Tasks:**
- [ ] **5.1.1**: Create app icon (1024×1024 PNG)
- [ ] **5.1.2**: Write App Store description
- [ ] **5.1.3**: Create screenshots
- [ ] **5.1.4**: Set up privacy policy (minimal data collection)
- [ ] **5.1.5**: Add help/tutorial screens (optional for MVP)

**Deliverable**: App Store listing draft.

---

#### Milestone 5.2: Testing & Bug Fixes

**Tasks:**
- [ ] **5.2.1**: QA on:
  - iPhone 12 (minimum supported)
  - iPad (6th gen or later)
  - iOS 15.0+ (or later, TBD)
  
- [ ] **5.2.2**: Crash reporting setup (Firebase Crashlytics, Sentry, etc.)
- [ ] **5.2.3**: Fix critical bugs found in testing

**Deliverable**: Known issues list; app stable for submission.

---

#### Milestone 5.3: App Store Submission

**Tasks:**
- [ ] **5.3.1**: Obtain Apple Developer Program membership
- [ ] **5.3.2**: Code signing & provisioning profiles
- [ ] **5.3.3**: App Store Connect setup
- [ ] **5.3.4**: Submit for review
- [ ] **5.3.5**: Address review feedback

**Deliverable**: App on App Store (or TestFlight beta).

---

## Technical Deep Dive: Swift/C Interoperability

### Using Swift Blog Techniques

Following the [Swift Blog recommendations](https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/):

#### 1. Module Map (`Sources/OpenRCT2Core/include/module.modulemap`)

```modulemap
module OpenRCT2Core {
  header "OpenRCT2.h"
  export *
}
```

Create a minimal shim header `OpenRCT2.h` exposing only what Swift needs:

```c
#ifndef OPENRCT2_H
#define OPENRCT2_H

#include <stdint.h>
#include <stddef.h>

// Opaque context pointer
typedef struct OpenRCT2ContextImpl* OpenRCT2Context;

// Version/info
const char* OpenRCT2_GetVersion(void);

// Lifecycle
OpenRCT2Context OpenRCT2_Create(void);
void OpenRCT2_Initialize(OpenRCT2Context ctx);
void OpenRCT2_RunFrame(OpenRCT2Context ctx);
void OpenRCT2_GetFrameBuffer(OpenRCT2Context ctx, uint8_t** outBuffer, uint32_t* outWidth, uint32_t* outHeight);
void OpenRCT2_Destroy(OpenRCT2Context ctx);

#endif
```

#### 2. API Notes (`Sources/OpenRCT2Core/include/OpenRCT2.apinotes`)

```yaml
---
Name: OpenRCT2Core
Tags:
  - Name: OpenRCT2ContextImpl
    SwiftImportAs: reference
    SwiftReleaseOp: OpenRCT2_Destroy
    SwiftRetainOp: NULL

Functions:
  - Name: OpenRCT2_Create
    SwiftReturnOwnership: retained
  
  - Name: OpenRCT2_GetFrameBuffer
    SwiftName: OpenRCT2Context.getFrameBuffer(self:width:height:)
```

This makes the Swift API cleaner:

```swift
let context = OpenRCT2.create()  // Automatic memory management
context.getFrameBuffer(&buffer, &width, &height)
// context is auto-released when out of scope
```

#### 3. CMake Integration

OpenRCT2 uses CMake. For iOS SPM integration:

**Option A: Pre-built Binary**
- Build OpenRCT2 once for iOS as a `.xcframework`
- Include in Swift package
- Simpler but less flexible

**Option B: SPM Build Plugins**
- Use Swift Package Manager build plugins to invoke CMake
- More complex but keeps single source

For MVP, recommend **Option A** (pre-built).

---

## File Structure Proposal

```
OpenRCT2-iOS/
│
├── Package.swift                           # SPM manifest
├── CMakeLists.txt                          # For building C++ core
├── README.md                               # Setup instructions
├── OPENRCT2_IOS_INITIATIVE.md              # This document
│
├── Sources/
│   │
│   ├── OpenRCT2Core/                       # C wrapper layer
│   │   ├── include/
│   │   │   ├── module.modulemap
│   │   │   ├── OpenRCT2.apinotes
│   │   │   ├── OpenRCT2.h                  # Public C API
│   │   │   └── OpenRCT2Shim.h              # Internal shim
│   │   │
│   │   ├── OpenRCT2Shim.cpp                # C++ glue code
│   │   └── (Links to: ../../src/openrct2/)
│   │
│   └── OpenRCT2App/                        # Swift iOS app
│       ├── GameViewController.swift
│       ├── GameRenderer.swift
│       ├── TouchInputHandler.swift
│       ├── ContentView.swift               # SwiftUI
│       └── Resources/
│           └── Assets.xcassets/
│
├── Tests/
│   ├── OpenRCT2CoreTests/
│   │   └── BasicInitTests.swift
│   └── OpenRCT2AppTests/
│       └── RenderTests.swift
│
├── Rendering/
│   ├── MetalRenderer.swift (Phase 4)
│   └── SDLSurfaceRenderer.swift
│
└── [Linked: OpenRCT2 core source]
```

---

## Key Code Linkage References

| Feature | File(s) | Status |
|---------|---------|--------|
| **Game Loop** | [Context.cpp#L1241](src/openrct2/Context.cpp#L1241) | Ready - just needs iOS UI wrapper |
| **Rendering Engine** | [IDrawingEngine.h](src/openrct2/drawing/IDrawingEngine.h) | Ready - abstract enough |
| **Software Rasterizer** | [X8DrawingEngine.cpp](src/openrct2/drawing/X8DrawingEngine.cpp) | Ready - CPU rendering unchanged |
| **Input System** | [UiContext.cpp#L400-600](src/openrct2-ui/UiContext.cpp#L400) | Partial - need touch → SDL event mapper |
| **Android Reference** | [MainActivity.java](src/openrct2-android/app/src/main/java/io/openrct2/MainActivity.java) | Good template |
| **Platform UI** | [UiContext.macOS.mm](src/openrct2-ui/UiContext.macOS.mm) | Good reference for platform-specific code |

---

## Dependencies & Build Requirements

### Required
- Xcode 14.0+
- iOS 15.0+ (deployment target)
- Swift 5.7+
- CMake 3.20+ (for building C++ core)

### Build Process
```bash
# 1. Build OpenRCT2 C++ core as iOS framework
cd OpenRCT2-iOS
mkdir build-ios
cd build-ios
cmake .. -DCMAKE_TOOLCHAIN_FILE=... -DIOS=ON
make

# 2. Create .xcframework
# (Xcode build system handles)

# 3. Integrate with SPM
# Swift package links pre-built binary
```

### Runtime Dependencies (Optional)
- RCT2 data files (required for full gameplay, ~100 MB)
- Optional: SDL2 for iOS (may need to build custom)

---

## Risk Assessment & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|-----------|
| **SDL2 iOS Support Gaps** | High | Medium | Pre-screen SDL2 iOS capability; fork/patch if needed. Have Metal fallback ready. |
| **C++ ABI Compatibility** | High | Low | Test linking on real iOS device early. Use Clang, not GCC. |
| **Performance (CPU renderin)** | Medium | Medium | Implement dirty rectangle optimization. Profile frame rendering. Metal path for Phase 4. |
| **Asset File Loading** | Medium | Low | Sandbox constraints; iOS file APIs differ from desktop. Plan early. |
| **App Store Review** | Low | Low | Follow guidelines (open source, no embedded browser). Prepare for rejection, have appeals ready. |
| **Memory Usage** | Medium | Medium | RCT2 can use 200-400 MB. Modern iPhones have 3-6 GB. iPad larger. Acceptable. |

---

## Estimated Timeline & Resource

| Phase | Duration | Effort | People |
|-------|----------|--------|--------|
| **Phase 1 (PoC)** | 2-3 weeks | 40-60 hrs | 1-2 developers |
| **Phase 2 (Input)** | 2 weeks | 30-40 hrs | 1 |
| **Phase 3 (Assets)** | 2 weeks | 30-40 hrs | 1 |
| **Phase 4 (Optimization)** | 3 weeks | 60-80 hrs | 1-2 |
| **Phase 5 (Polish)** | 2 weeks | 30-40 hrs | 1 |
| **TOTAL** | ~13 weeks | ~200 hrs | 1-2 devs |

---

## Success Criteria

### MVP Success
- ✅ App runs on iOS simulator and real device (iPhone 12+)
- ✅ Initializes OpenRCT2 core without crashes
- ✅ Renders frame buffer to screen at 60 FPS
- ✅ Touch input works (viewport panning at minimum)
- ✅ Playable for >= 10 minutes without crash
- ✅ Video proof-of-concept demo

### Phase 2+ Success
- ✅ Full touch controls (pan, zoom, click UI buttons)
- ✅ Load/save parks
- ✅ Asset bundle integrated
- ✅ ~30 FPS minimum on iPad, ~60 FPS on iPhone 12+

### Production Success
- ✅ App Store available
- ✅ 1000+ downloads
- ✅ Positive reviews (4.0+ rating)
- ✅ <2% crash rate

---

## References & Resources

1. **Swift C Interop Blog**: https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/
2. **SDL2 iOS Guide**: https://wiki.libsdl.org/SDL2/README/iOS
3. **OpenRCT2 GitHub**: https://github.com/OpenRCT2
4. **Apple Metal Programming Guide**: https://developer.apple.com/metal/
5. **SPM Docs**: https://swift.org/package-manager/
6. **iOS Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

---

## Appendix: SDL→Metal Final Analysis

### Why Software Rendering Alone Could Work

1. **Modern iOS Hardware**: iPhone 12 (A14 Bionic) and later have:
   - 6-core CPU @ 3.1 GHz
   - Sufficient cache for frame buffer operations
   - NEON/ARM intrinsics for vectorized operations

2. **Optimization Techniques Available**:
   - Dirty rectangle optimization (already in X8DrawingEngine)
   - SIMD palette conversion (8-bit → RGBA)
   - Mipmapped texture scaling for zoom operations

3. **Bandwidth Analysis**:
   - Frame size: 1024×768 = 786,432 pixels
   - Frame buffer: 786 KB (8-bit) → ~3.1 MB (32-bit RGBA)
   - @ 60 FPS: ~186 MB/sec write bandwidth
   - A14 Bionic: ~100 GB/sec memory bandwidth available
   - Conclusion: **Plenty of headroom**

### Where Metal Becomes Essential

1. **Battery Life**: Software rendering continuously burns CPU → 2-3 hr battery
2. **Sustained Performance**: Thermal throttling on extended play (>1 hour)
3. **Resolution Scaling**: iPad Pros (1536×2048 native) would struggle
4. **Future Features**: Advanced graphics, dynamic lighting, particle effects

### Recommendation: Phased Approach

```
Week 1-2:   Software → SDL Surface (MVP)
            ↓
Week 3-4:   Profile: If FPS < 50 on iPhone 12, do Metal
            ↓
Week 5-8:   Metal + optimization (Phase 4)
```

If software hits 55+ FPS on iPhone 12, the system is **viable**. Optimization can wait.

---

## Next Steps

1. **Approved**: Fund Phase 1 (PoC setup & initialization)
2. **Create**: GitHub issues for each milestone
3. **Assign**: Lead developer and secondary reviewer
4. **Schedule**: 2-3 week sprint for Phase 1
5. **Report**: Weekly progress updates; decision gate before Phase 2
6. **Community**: Consider early beta testers; public GitHub discussions

---

**Document Version**: 1.0  
**Last Updated**: January 24, 2026  
**Author**: AI Copilot (Architecture & Spec)  
**Reviewers**: [TBD - Lead iOS Developer]
