# OpenRCT2 visionOS MVP Epic

> **Status**: Active Development  
> **Target**: visionOS 2.0+ (Apple Vision Pro)  
> **Approach**: Native SwiftUI + RealityKit + X8DrawingEngine Software Renderer  
> **Estimated Effort**: ~105 hours (8-10 weeks @ 10-12 hrs/week)

---

## Executive Summary

This document defines the Minimum Viable Product (MVP) for porting OpenRCT2 to visionOS using a **native SwiftUI + RealityKit approach** with the existing **X8DrawingEngine software renderer**. Unlike the archived SDL-based iOS approach, this implementation leverages Swift/C++ interoperability (Swift 5.9+) to directly integrate with OpenRCT2's rendering pipeline, using **TextureResource.DrawableQueue** for 90/120 Hz display updates.

### Why visionOS?

1. **Unique Experience**: Theme park management on a spatial computing platform offers an immersive perspective unavailable on traditional devices
2. **Native Integration**: SwiftUI and RealityKit provide first-class visionOS support without SDL abstraction layers
3. **Performance**: DrawableQueue + Metal compute shaders enable 90/120 Hz rendering without frame drops
4. **Input Paradigm**: visionOS indirect gestures (look + pinch) naturally map to cursor-based interaction

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| C++ Interop | Swift 5.9+ direct | No C wrapper needed; `module.modulemap` + `-cxx-interoperability-mode=default` |
| Display Pipeline | TextureResource.DrawableQueue | 90/120 Hz capable vs CGImage/MTLTexture.replace() frame drops |
| Palette Conversion | Metal Compute Shader | GPU-parallel, ~10× faster than CPU |
| UI Context | VisionOSUiContext | Native `IUiContext` impl bypassing SDL |
| Build System | CMake + vcpkg | Consistent with OpenRCT2 ecosystem; new `arm64-xros` triplet |

### Core Architectural Insight

OpenRCT2's `X8DrawingEngine` produces a **platform-agnostic** `uint8_t*` pixel buffer with indexed 8-bit color. This buffer is completely independent of SDL—SDL is only used for:
- Window management → **SwiftUI Window**
- Input events → **UIKit gestures → CursorState**
- Displaying pixels → **Metal texture upload**
- Audio playback → **AVFoundation**

---

## Technical Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          visionOS App (SwiftUI)                         │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐    ┌─────────────────┐    ┌─────────────────────┐  │
│  │   RealityView  │    │  Spatial Tap/   │    │    AVFoundation     │  │
│  │   + Plane      │◄───│  Drag Gesture   │    │    AVAudioEngine    │  │
│  │   Entity       │    │  Handlers       │    │                     │  │
│  └───────▲────────┘    └────────┬────────┘    └──────────▲──────────┘  │
│          │                      │                        │              │
│  ┌───────┴────────┐    ┌────────▼────────┐    ┌─────────┴───────────┐  │
│  │ TextureResource│    │  InputBridge    │    │    AudioBridge      │  │
│  │ .DrawableQueue │    │  (Swift)        │    │    (Swift)          │  │
│  │ @90/120 Hz     │    │                 │    │                     │  │
│  └───────▲────────┘    └────────┬────────┘    └──────────▲──────────┘  │
│          │                      │                        │              │
│  ┌───────┴────────┐             │                        │              │
│  │ Metal Compute  │             │                        │              │
│  │ Shader (GPU)   │◄────────────┤                        │              │
│  │ Palette Conv.  │             │                        │              │
│  └───────▲────────┘             │                        │              │
│          │                      │                        │              │
├──────────┼──────────────────────┼────────────────────────┼──────────────┤
│          │  Swift 5.9+ C++ Interop (Direct, No C Shim)  │              │
├──────────┼──────────────────────┼────────────────────────┼──────────────┤
│          │                      │                        │              │
│  ┌───────┴────────┐    ┌────────▼────────┐    ┌─────────┴───────────┐  │
│  │VisionOSUiContext│    │   CursorState   │    │   IAudioMixer       │  │
│  │ (IUiContext)   │◄───│   + InputEvents │    │   + IAudioSource    │  │
│  │ GetPixelBuffer │    │                 │    │                     │  │
│  └───────▲────────┘    └────────▲────────┘    └──────────▲──────────┘  │
│          │                      │                        │              │
│  ┌───────┴────────┐             │                        │              │
│  │ X8DrawingEngine│             │                        │              │
│  │ uint8_t* _bits │─────────────┴────────────────────────┘              │
│  │ + GamePalette  │                                                     │
│  └────────────────┘                                                     │
│                         OpenRCT2 Game Core (C++)                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interop | Swift 5.9+ C++ | Direct calls without C shim; cleaner API |
| Display | TextureResource.DrawableQueue | 90/120 Hz without frame drops |
| Palette Conversion | Metal Compute Shader | ~10× faster than CPU; parallel |
| Input | Gaze + Pinch → CursorState | Natural visionOS interaction |
| Audio | AVFoundation AVAudioEngine | Low latency, full iOS API access |
| Build | CMake + vcpkg | Consistent with OpenRCT2 ecosystem |

### Reference: CopyBitsToTexture Pattern

Our Metal compute shader mirrors the existing `CopyBitsToTexture()` function from 
[HardwareDisplayDrawingEngine.cpp](src/openrct2-ui/drawing/engines/HardwareDisplayDrawingEngine.cpp#L275):

```cpp
// Original SDL pattern (for reference)
void CopyBitsToTexture(SDL_Texture* texture, uint8_t* src, 
                       int32_t width, int32_t height, const uint32_t* palette)
{
    void* pixels;
    int32_t pitch;
    if (SDL_LockTexture(texture, nullptr, &pixels, &pitch) == 0)
    {
        uint32_t* dst = static_cast<uint32_t*>(pixels);
        for (int32_t i = width * height; i > 0; i--)
        {
            *dst++ = palette[*src++];  // Index → ARGB lookup
        }
        SDL_UnlockTexture(texture);
    }
}
```

Our Metal shader does the same operation but:
1. Runs on GPU in parallel (~10× faster)
2. Writes to DrawableQueue texture (90/120 Hz ready)
3. Handles BGRA→RGBA conversion inline

### Key Components

#### 1. X8DrawingEngine Integration

The software renderer lives in `src/openrct2/drawing/X8DrawingEngine.h`:

```cpp
class X8DrawingEngine : public IDrawingEngine {
protected:
    uint8_t* _bits = nullptr;      // 8-bit indexed pixel buffer
    uint32_t _width = 0;
    uint32_t _height = 0;
    int32_t _pitch = 0;            // NOTE: offset from width, not stride
    RenderTarget _mainRT;
    // ...
};
```

**Critical**: `RenderTarget.pitch` is an **offset** from width. Full line stride = `width + pitch`.

#### 2. Palette System (BGRA Format)

From `src/openrct2/drawing/ColourPalette.h`:

```cpp
struct BGRAColour {
    uint8_t Blue{};
    uint8_t Green{};
    uint8_t Red{};
    uint8_t Alpha{};
};

using GamePalette = std::array<BGRAColour, 256>;
```

**Important**: The palette is **BGRA** (not RGBA). Conversion to Metal's RGBA format requires channel reordering.

#### 3. IDrawingEngine Interface

From `src/openrct2/drawing/IDrawingEngine.h`:

```cpp
interface IDrawingEngine {
    virtual void Initialise() = 0;
    virtual void Resize(uint32_t width, uint32_t height) = 0;
    virtual void SetPalette(const GamePalette& palette) = 0;
    virtual void Invalidate(int32_t left, int32_t top, int32_t right, int32_t bottom) = 0;
    virtual void BeginDraw() = 0;
    virtual void EndDraw() = 0;
    virtual void PaintWindows() = 0;
    // ...
};
```

#### 4. IUiContext Interface (Platform Abstraction)

From `src/openrct2/ui/UiContext.h`:

```cpp
interface IUiContext {
    virtual void CreateWindow() = 0;
    virtual CursorState GetCursorState() = 0;
    virtual std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory() = 0;
    virtual void Draw() = 0;
    virtual void ProcessMessages() = 0;
    // ...
};
```

We implement `IUiContext` for visionOS, bridging to SwiftUI.

---

## Swift/C++ Interoperability

### Module Map Configuration

Create `Sources/OpenRCT2Core/include/module.modulemap`:

```modulemap
module OpenRCT2Core {
    umbrella header "OpenRCT2Core.h"
    
    export *
    module * { export * }
    
    // Explicit submodules for key interfaces
    module DrawingEngine {
        header "drawing/IDrawingEngine.h"
        header "drawing/X8DrawingEngine.h"
        header "drawing/RenderTarget.h"
        header "drawing/ColourPalette.h"
        requires cplusplus
    }
    
    module UiContext {
        header "ui/UiContext.h"
        requires cplusplus
    }
}
```

### API Notes for Swift Naming

Create `Sources/OpenRCT2Core/include/OpenRCT2Core.apinotes`:

```yaml
Name: OpenRCT2Core
Classes:
  - Name: X8DrawingEngine
    SwiftName: SoftwareRenderer
    Methods:
      - Selector: "BeginDraw"
        SwiftName: "beginFrame()"
      - Selector: "EndDraw"
        SwiftName: "endFrame()"
Structs:
  - Name: BGRAColour
    SwiftName: PaletteColor
  - Name: RenderTarget
    SwiftName: FrameBuffer
```

### Build Settings (Package.swift)

```swift
// Package.swift
let package = Package(
    name: "OpenRCT2-visionOS",
    platforms: [.visionOS(.v2)],
    products: [
        .library(name: "OpenRCT2Core", targets: ["OpenRCT2Core"]),
        .executable(name: "OpenRCT2", targets: ["OpenRCT2App"])
    ],
    targets: [
        .target(
            name: "OpenRCT2Core",
            dependencies: [],
            path: "src/openrct2",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("__VISIONOS__"),
                .unsafeFlags(["-std=c++20"])
            ]
        ),
        .executableTarget(
            name: "OpenRCT2App",
            dependencies: ["OpenRCT2Core"],
            path: "Sources/OpenRCT2App",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ],
    cxxLanguageStandard: .cxx20
)
```

---

## Pixel Buffer → RealityKit TextureResource Pipeline

### Why DrawableQueue over MTLTexture.replace()?

**Critical for 90/120 Hz**: visionOS requires consistent frame delivery at 90 Hz (or 120 Hz on Vision Pro). Using `MTLTexture.replace()` can cause frame drops due to synchronization issues. `TextureResource.DrawableQueue` provides:

1. **Triple buffering** - No GPU/CPU sync stalls
2. **Automatic frame pacing** - Integrated with RealityKit's render loop
3. **Low latency** - Frames appear within single refresh cycle

### DrawableQueue Renderer

```swift
import RealityKit
import Metal

final class OpenRCT2Renderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var drawableQueue: TextureResource.DrawableQueue?
    private var textureResource: TextureResource?
    
    // Compute shader for GPU palette conversion
    private var paletteConvertPipeline: MTLComputePipelineState?
    private var paletteBuffer: MTLBuffer?
    private var indexedBuffer: MTLBuffer?
    
    // Dimensions
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal not available")
        }
        self.device = device
        self.commandQueue = queue
        
        setupComputePipeline()
    }
    
    private func setupComputePipeline() {
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "convertIndexedToRGBA") else {
            return
        }
        paletteConvertPipeline = try? device.makeComputePipelineState(function: function)
        
        // Allocate palette buffer (256 BGRA entries = 1024 bytes)
        paletteBuffer = device.makeBuffer(length: 256 * 4, options: .storageModeShared)
    }
    
    /// Create or resize DrawableQueue for given dimensions
    func resize(width: Int, height: Int) async throws {
        guard width != currentWidth || height != currentHeight else { return }
        
        currentWidth = width
        currentHeight = height
        
        // Create DrawableQueue descriptor
        let descriptor = TextureResource.DrawableQueue.Descriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            usage: [.shaderRead, .shaderWrite],
            mipmapsMode: .none
        )
        
        // Create drawable queue (triple-buffered by default)
        drawableQueue = try TextureResource.DrawableQueue(descriptor)
        
        // Create TextureResource from DrawableQueue
        textureResource = try await TextureResource(drawableQueue: drawableQueue!)
        
        // Resize indexed buffer for compute shader input
        indexedBuffer = device.makeBuffer(
            length: width * height,  // 8-bit indexed
            options: .storageModeShared
        )
    }
    
    /// Update palette from game engine (BGRA format)
    func updatePalette(_ palette: UnsafePointer<UInt8>, count: Int) {
        guard let buffer = paletteBuffer else { return }
        memcpy(buffer.contents(), palette, min(count * 4, 1024))
    }
    
    /// Upload frame using DrawableQueue (90/120 Hz capable)
    /// Pattern follows CopyBitsToTexture from HardwareDisplayDrawingEngine.cpp:275
    func uploadFrame(
        bits: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        pitch: Int
    ) {
        guard let queue = drawableQueue,
              let pipeline = paletteConvertPipeline,
              let paletteBuffer = paletteBuffer,
              let indexedBuffer = indexedBuffer,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Copy indexed pixels to GPU buffer (handling pitch/stride)
        let stride = width + pitch
        let dst = indexedBuffer.contents().assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            let srcRow = bits + y * stride
            let dstRow = dst + y * width
            memcpy(dstRow, srcRow, width)
        }
        
        // Get next drawable from queue
        guard let drawable = try? queue.nextDrawable() else { return }
        
        // Run compute shader for palette conversion on GPU
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(indexedBuffer, offset: 0, index: 0)
        encoder.setBuffer(paletteBuffer, offset: 0, index: 1)
        encoder.setTexture(drawable.texture, index: 0)
        
        // Dispatch threads
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        
        // Present drawable to RealityKit
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }
    
    var texture: TextureResource? { textureResource }
}
```

### Metal Compute Shader for GPU Palette Conversion

**~10× faster than CPU conversion** by parallelizing across all pixels:

```metal
// PaletteConvert.metal
#include <metal_stdlib>
using namespace metal;

struct PaletteEntry {
    uchar blue;   // BGRA order from OpenRCT2
    uchar green;
    uchar red;
    uchar alpha;
};

kernel void convertIndexedToRGBA(
    device const uchar* indexedBuffer [[buffer(0)]],
    device const PaletteEntry* palette [[buffer(1)]],
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    uint srcIdx = gid.y * outTexture.get_width() + gid.x;
    uchar colorIndex = indexedBuffer[srcIdx];
    PaletteEntry color = palette[colorIndex];
    
    // BGRA → RGBA conversion
    half4 rgba = half4(
        half(color.red) / 255.0h,
        half(color.green) / 255.0h,
        half(color.blue) / 255.0h,
        half(color.alpha) / 255.0h
    );
    
    outTexture.write(rgba, gid);
}
```

---

## RealityView Display Integration

### Main App Structure

```swift
// OpenRCT2App.swift
import SwiftUI
import RealityKit

@main
struct OpenRCT2App: App {
    @StateObject private var gameEngine = GameEngine()
    
    var body: some Scene {
        // Main game window (2D panel in visionOS)
        WindowGroup {
            GameView()
                .environmentObject(gameEngine)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1280, height: 720)
        
        // Future: Immersive 3D park view
        // ImmersiveSpace(id: "parkView") {
        //     ImmersiveParkView()
        // }
    }
}
```

### RealityView Game Display

Using `RealityView` with `TextureResource` for optimal visionOS integration:

```swift
// GameView.swift
import SwiftUI
import RealityKit

struct GameView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var gameEntity: ModelEntity?
    
    var body: some View {
        RealityView { content in
            // Create flat plane to display game
            let mesh = MeshResource.generatePlane(width: 1.28, height: 0.72)
            let entity = ModelEntity(mesh: mesh)
            
            // Initial material (replaced when texture ready)
            var material = UnlitMaterial()
            entity.model?.materials = [material]
            
            content.add(entity)
            gameEntity = entity
            
        } update: { content in
            // Update texture when game renders new frame
            if let texture = gameEngine.renderer.texture {
                var material = UnlitMaterial()
                material.color = .init(texture: .init(texture))
                gameEntity?.model?.materials = [material]
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    // Convert tap to game coordinates
                    let location = value.location3D
                    gameEngine.handleTap(at: location)
                }
        )
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    gameEngine.updateCursor(
                        position: value.location3D,
                        state: .dragging
                    )
                }
                .onEnded { value in
                    gameEngine.updateCursor(
                        position: value.location3D,
                        state: .released
                    )
                }
        )
        .onAppear {
            Task {
                await gameEngine.start()
            }
        }
        .onDisappear {
            gameEngine.stop()
        }
    }
}
```

### Coordinate Mapping (3D → 2D Game Space)

```swift
extension GameEngine {
    /// Convert RealityKit 3D location to game pixel coordinates
    func convertToGameCoordinates(_ location3D: SIMD3<Float>) -> CGPoint {
        // Plane is 1.28m × 0.72m, game is 1280×720 pixels
        // Map from [-0.64, 0.64] × [-0.36, 0.36] to [0, 1280] × [0, 720]
        let x = (location3D.x + 0.64) / 1.28 * CGFloat(gameWidth)
        let y = (0.36 - location3D.y) / 0.72 * CGFloat(gameHeight)  // Y inverted
        return CGPoint(x: x, y: y)
    }
}
```

---

## VisionOSUiContext Implementation

The core platform abstraction implementing `IUiContext` for visionOS:

### C++ Interface (VisionOSUiContext.h)

```cpp
// src/openrct2-ui/visionos/VisionOSUiContext.h
#pragma once

#include <openrct2/ui/UiContext.h>
#include <openrct2/drawing/IDrawingEngine.h>

namespace OpenRCT2::Ui::VisionOS
{
    // Forward declaration for Swift interop
    class VisionOSDrawingEngine;
    
    class VisionOSUiContext final : public IUiContext
    {
    private:
        int32_t _width = 1280;
        int32_t _height = 720;
        CursorState _cursorState{};
        std::unique_ptr<VisionOSDrawingEngine> _drawingEngine;
        
        // Swift callback pointers (set during initialization)
        void* _swiftContext = nullptr;
        
    public:
        VisionOSUiContext();
        ~VisionOSUiContext() override;
        
        // IUiContext implementation
        void CreateWindow() override;
        void CloseWindow() override;
        void RecreateWindow() override;
        void* GetWindow() override;
        
        int32_t GetWidth() override { return _width; }
        int32_t GetHeight() override { return _height; }
        ScaleQuality GetScaleQuality() override { return ScaleQuality::Linear; }
        
        void SetCursorTrap(bool value) override {}  // No cursor trap on visionOS
        CursorState GetCursorState() override { return _cursorState; }
        void SetCursorPosition(const ScreenCoordsXY& screenCoords) override;
        void SetCursorVisible(bool value) override {}
        
        bool SetClipboardText(std::string_view text) override;
        
        void ProcessMessages() override;
        void Draw() override;
        
        // Drawing engine factory
        std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory() override;
        
        // Swift interop - called from Swift side
        void SetSwiftContext(void* context) { _swiftContext = context; }
        void UpdateCursorFromSwift(int32_t x, int32_t y, bool leftDown, bool rightDown);
        void NotifyResize(int32_t width, int32_t height);
        
        // Access pixel buffer for Swift rendering
        uint8_t* GetPixelBuffer();
        uint32_t GetBufferWidth();
        uint32_t GetBufferHeight();
        int32_t GetBufferPitch();
        const uint32_t* GetPalette();
    };
    
    // Factory function for Swift
    std::unique_ptr<IUiContext> CreateVisionOSUiContext();
    
} // namespace OpenRCT2::Ui::VisionOS
```

### Swift Bridge (GameEngine.swift)

```swift
// Sources/OpenRCT2App/GameEngine.swift
import Foundation
import RealityKit
import OpenRCT2Core

@MainActor
final class GameEngine: ObservableObject {
    @Published private(set) var renderer: OpenRCT2Renderer
    private var uiContext: VisionOSUiContext?
    private var gameThread: Thread?
    private var isRunning = false
    
    // Input state from SwiftUI gestures
    private var inputBridge = InputBridge()
    
    var gameWidth: Int { Int(uiContext?.GetBufferWidth() ?? 1280) }
    var gameHeight: Int { Int(uiContext?.GetBufferHeight() ?? 720) }
    
    init() {
        renderer = OpenRCT2Renderer()
    }
    
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        
        // Create visionOS UI context
        uiContext = CreateVisionOSUiContext()
        
        // Pass Swift context pointer for callbacks
        let unmanaged = Unmanaged.passUnretained(self)
        uiContext?.SetSwiftContext(unmanaged.toOpaque())
        
        // Initialize renderer with game dimensions
        try? await renderer.resize(width: gameWidth, height: gameHeight)
        
        // Start game loop on background thread
        gameThread = Thread { [weak self] in
            self?.gameLoop()
        }
        gameThread?.qualityOfService = .userInteractive
        gameThread?.start()
    }
    
    func stop() {
        isRunning = false
        gameThread?.cancel()
        gameThread = nil
    }
    
    private func gameLoop() {
        // Initialize OpenRCT2 game context
        guard let context = uiContext else { return }
        
        // Main game loop - called from C++ thread
        while isRunning && !Thread.current.isCancelled {
            // Update input from Swift side
            let input = inputBridge.getCursorState()
            context.UpdateCursorFromSwift(
                input.x, input.y, input.left, input.right
            )
            
            // Process game tick
            context.ProcessMessages()
            context.Draw()
            
            // Upload frame to RealityKit
            if let bits = context.GetPixelBuffer(),
               let palette = context.GetPalette() {
                // Convert palette to bytes for Metal
                renderer.updatePalette(
                    UnsafeRawPointer(palette).assumingMemoryBound(to: UInt8.self),
                    count: 256
                )
                
                renderer.uploadFrame(
                    bits: bits,
                    width: Int(context.GetBufferWidth()),
                    height: Int(context.GetBufferHeight()),
                    pitch: Int(context.GetBufferPitch())
                )
            }
            
            // Target ~40fps game tick (rendering is 90Hz via DrawableQueue)
            Thread.sleep(forTimeInterval: 0.025)
        }
    }
    
    // MARK: - Input Handling
    
    func handleTap(at location3D: SIMD3<Float>) {
        let point = convertToGameCoordinates(location3D)
        inputBridge.simulateTap(at: point)
    }
    
    func updateCursor(position: SIMD3<Float>, state: VisionOSInputState) {
        let point = convertToGameCoordinates(position)
        inputBridge.updateCursor(position: point, state: state)
    }
}
```

---

## Input System Bridge

### CursorState Mapping

```swift
// InputBridge.swift
import Foundation

enum VisionOSInputState {
    case idle
    case hovering
    case dragging
    case released
}

final class InputBridge {
    // Maps to OpenRCT2's CursorState
    private var cursorX: Int32 = 0
    private var cursorY: Int32 = 0
    private var leftButtonDown: Bool = false
    private var rightButtonDown: Bool = false
    
    /// Called from SwiftUI gesture handlers
    func updateCursor(position: CGPoint, state: VisionOSInputState) {
        cursorX = Int32(position.x)
        cursorY = Int32(position.y)
        
        switch state {
        case .idle:
            leftButtonDown = false
            rightButtonDown = false
        case .hovering:
            leftButtonDown = false
        case .dragging:
            leftButtonDown = true
        case .released:
            leftButtonDown = false
        }
    }
    
    /// Called from C++ via interop
    func getCursorState() -> (x: Int32, y: Int32, left: Bool, right: Bool) {
        return (cursorX, cursorY, leftButtonDown, rightButtonDown)
    }
    
    /// Long press simulates right-click for context menus
    func handleLongPress(at position: CGPoint) {
        cursorX = Int32(position.x)
        cursorY = Int32(position.y)
        rightButtonDown = true
        
        // Release after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rightButtonDown = false
        }
    }
}
```

### visionOS Spatial Input Considerations

For immersive experiences, consider:
- **Indirect input**: Look at UI element + pinch to select (maps to click)
- **Direct input**: Touch UI panel directly (maps to cursor position + click)
- **Two-handed pinch**: Could map to right-click or zoom

---

## visionOS Build Configuration

### CMake Toolchain File

Create `cmake/visionos-arm64.toolchain.cmake`:

```cmake
# visionos-arm64.toolchain.cmake
# Toolchain for building OpenRCT2 for visionOS (Apple Vision Pro)

set(CMAKE_SYSTEM_NAME visionOS)
set(CMAKE_SYSTEM_VERSION 2.0)
set(CMAKE_SYSTEM_PROCESSOR arm64)

# visionOS SDK
set(CMAKE_OSX_SYSROOT xros)
set(CMAKE_OSX_DEPLOYMENT_TARGET "2.0")
set(CMAKE_OSX_ARCHITECTURES arm64)

# Compiler settings
set(CMAKE_C_COMPILER xcrun clang)
set(CMAKE_CXX_COMPILER xcrun clang++)

set(CMAKE_C_FLAGS_INIT "-target arm64-apple-xros2.0")
set(CMAKE_CXX_FLAGS_INIT "-target arm64-apple-xros2.0 -std=c++20")

# Disable features not available on visionOS
set(DISABLE_DISCORD_RPC ON CACHE BOOL "Discord not available on visionOS")
set(DISABLE_GOOGLE_BENCHMARK ON CACHE BOOL "Benchmarks not needed")
set(DISABLE_HTTP ON CACHE BOOL "Use URLSession instead")

# visionOS-specific defines
add_compile_definitions(__VISIONOS__=1)
add_compile_definitions(OPENRCT2_PLATFORM_VISIONOS=1)

# Find visionOS frameworks
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

### visionOS Simulator Toolchain

Create `cmake/visionos-simulator.toolchain.cmake`:

```cmake
# visionos-simulator.toolchain.cmake
# Toolchain for visionOS Simulator (arm64 Mac)

set(CMAKE_SYSTEM_NAME visionOS)
set(CMAKE_SYSTEM_VERSION 2.0)
set(CMAKE_SYSTEM_PROCESSOR arm64)

# Simulator SDK
set(CMAKE_OSX_SYSROOT xrossimulator)
set(CMAKE_OSX_DEPLOYMENT_TARGET "2.0")
set(CMAKE_OSX_ARCHITECTURES arm64)

set(CMAKE_C_FLAGS_INIT "-target arm64-apple-xros2.0-simulator")
set(CMAKE_CXX_FLAGS_INIT "-target arm64-apple-xros2.0-simulator -std=c++20")

add_compile_definitions(__VISIONOS__=1)
add_compile_definitions(__VISIONOS_SIMULATOR__=1)
add_compile_definitions(OPENRCT2_PLATFORM_VISIONOS=1)
```

### vcpkg Triplet

Create `vcpkg/triplets/community/arm64-xros.cmake`:

```cmake
# arm64-xros.cmake
# vcpkg triplet for visionOS arm64

set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME visionOS)
set(VCPKG_OSX_SYSROOT xros)
set(VCPKG_OSX_DEPLOYMENT_TARGET "2.0")

set(VCPKG_C_FLAGS "-target arm64-apple-xros2.0")
set(VCPKG_CXX_FLAGS "-target arm64-apple-xros2.0 -std=c++20")

# Disable ports not needed/available on visionOS
set(VCPKG_DISABLE_FEATURES
    sdl2
    discord-rpc
    benchmark
)
```

### vcpkg Simulator Triplet

Create `vcpkg/triplets/community/arm64-xros-simulator.cmake`:

```cmake
# arm64-xros-simulator.cmake
# vcpkg triplet for visionOS Simulator

set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME visionOS)
set(VCPKG_OSX_SYSROOT xrossimulator)
set(VCPKG_OSX_DEPLOYMENT_TARGET "2.0")

set(VCPKG_C_FLAGS "-target arm64-apple-xros2.0-simulator")
set(VCPKG_CXX_FLAGS "-target arm64-apple-xros2.0-simulator -std=c++20")

set(VCPKG_DISABLE_FEATURES
    sdl2
    discord-rpc
    benchmark
)
```

### Build Script

```bash
#!/bin/bash
# build-visionos.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-visionos"
SIMULATOR=${SIMULATOR:-0}

if [ "$SIMULATOR" = "1" ]; then
    TRIPLET="arm64-xros-simulator"
    TOOLCHAIN="visionos-simulator.toolchain.cmake"
else
    TRIPLET="arm64-xros"
    TOOLCHAIN="visionos-arm64.toolchain.cmake"
fi

# Bootstrap vcpkg if needed
if [ ! -f "vcpkg/vcpkg" ]; then
    ./vcpkg/bootstrap-vcpkg.sh
fi

# Install dependencies
./vcpkg/vcpkg install \
    --triplet=${TRIPLET} \
    icu \
    libpng \
    libzip \
    speexdsp \
    nlohmann-json

# Configure CMake
cmake -B "${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/${TOOLCHAIN}" \
    -DCMAKE_PREFIX_PATH="${SCRIPT_DIR}/vcpkg/installed/${TRIPLET}" \
    -DDISABLE_OPENGL=ON \
    -DDISABLE_SDL=ON \
    -DENABLE_VISIONOS=ON

# Build
cmake --build "${BUILD_DIR}" --parallel

echo "Build complete: ${BUILD_DIR}"
```

---

## Audio System (AVFoundation)

### Audio Bridge

```swift
// AudioBridge.swift
import AVFoundation

final class AudioBridge {
    private var audioEngine: AVAudioEngine?
    private var playerNodes: [String: AVAudioPlayerNode] = [:]
    private var audioFormat: AVAudioFormat?
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 2
        )
        
        try? audioEngine?.start()
    }
    
    /// Called from C++ IAudioMixer
    func playSound(buffer: UnsafePointer<Int16>, sampleCount: Int, sampleRate: Int) {
        guard let engine = audioEngine,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: Double(sampleRate),
                  channels: 2,
                  interleaved: true
              ) else { return }
        
        let frameCount = AVAudioFrameCount(sampleCount / 2) // stereo
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        pcmBuffer.frameLength = frameCount
        memcpy(pcmBuffer.int16ChannelData![0], buffer, sampleCount * 2)
        
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        playerNode.scheduleBuffer(pcmBuffer, completionHandler: { [weak engine] in
            engine?.detach(playerNode)
        })
        playerNode.play()
    }
    
    /// Set master volume (0.0 - 1.0)
    func setVolume(_ volume: Float) {
        audioEngine?.mainMixerNode.outputVolume = volume
    }
}
```

---

## Implementation Milestones

### Milestone 1: Xcode Project Foundation
**Effort**: ~15 hours | **Duration**: 1 week

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-001 | 4 | Create Xcode project with visionOS template | Builds and runs empty window |
| VOS-002 | 4 | Configure Swift/C++ interop | `module.modulemap`, `.apinotes`, `-cxx-interoperability-mode=default` |
| VOS-003 | 3 | Setup vcpkg triplet `arm64-xros-simulator` | Dependencies build for visionOS |
| VOS-004 | 2 | Create CMake toolchain file | Core lib compiles with `__VISIONOS__` |
| VOS-005 | 2 | Add visionOS preprocessor paths | Headers resolve, no SDL includes |

**Milestone Gate**: C++ OpenRCT2Core library compiles for visionOS simulator

### Milestone 2: VisionOSUiContext Implementation
**Effort**: ~20 hours | **Duration**: 1.5 weeks

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-010 | 6 | Implement `VisionOSUiContext` stub | Compiles, implements `IUiContext` |
| VOS-011 | 4 | Add `GetPixelBuffer()` accessor | Returns `X8DrawingEngine::_bits` |
| VOS-012 | 4 | Add `GetPalette()` accessor | Returns current `GamePalette` as `uint32_t*` |
| VOS-013 | 3 | Implement `ProcessMessages()` | Calls into game tick without blocking |
| VOS-014 | 3 | Implement `Draw()` | Triggers X8DrawingEngine render cycle |

**Milestone Gate**: Can call into OpenRCT2 game loop from Swift, pixel buffer accessible

### Milestone 3: Metal Texture Bridge (DrawableQueue)
**Effort**: ~20 hours | **Duration**: 1.5 weeks

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-020 | 6 | Create `OpenRCT2Renderer` with DrawableQueue | TextureResource created at 1280×720 |
| VOS-021 | 6 | Implement Metal compute shader | `convertIndexedToRGBA.metal` compiles |
| VOS-022 | 4 | Wire up palette buffer | Palette updates reflected in output |
| VOS-023 | 4 | Implement `uploadFrame()` | Drawable presented at 90 Hz cadence |

**Milestone Gate**: Static test image renders to DrawableQueue texture

### Milestone 4: RealityKit Display
**Effort**: ~15 hours | **Duration**: 1 week

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-030 | 4 | Create RealityView with plane entity | Plane visible in visionOS window |
| VOS-031 | 4 | Apply TextureResource to plane material | Static texture displayed |
| VOS-032 | 4 | Connect game loop to render pipeline | Live game renders on plane |
| VOS-033 | 3 | Handle window resize | Game resolution adapts to window |

**Milestone Gate**: OpenRCT2 renders live gameplay in visionOS window at ≥30fps

### Milestone 5: Gaze + Pinch Input
**Effort**: ~20 hours | **Duration**: 1.5 weeks

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-040 | 4 | Implement `InputBridge` class | Tracks cursor position and button state |
| VOS-041 | 4 | Add `SpatialTapGesture` handler | Tap → left click at gaze position |
| VOS-042 | 4 | Add `DragGesture` handler | Drag → cursor movement + left down |
| VOS-043 | 4 | Add `LongPressGesture` handler | Long press → right click (context menu) |
| VOS-044 | 4 | Map 3D coordinates to game pixels | Accurate coordinate transformation |

**Milestone Gate**: Can navigate UI, select tools, place objects via look+pinch

### Milestone 6: Audio via AVFoundation (Deferred)
**Effort**: ~15 hours | **Duration**: 1 week

| Ticket | Hours | Description | Acceptance Criteria |
|--------|-------|-------------|---------------------|
| VOS-050 | 4 | Create `AudioBridge` with AVAudioEngine | Engine starts without errors |
| VOS-051 | 5 | Implement IAudioContext adapter | C++ audio calls routed to Swift |
| VOS-052 | 3 | Wire up SFX playback | Sound effects play on game events |
| VOS-053 | 3 | Wire up music playback | Background music loops correctly |

**Milestone Gate**: Full audiovisual experience, music and SFX working

---

## Detailed File Structure

```
OpenRCT2-visionOS/
├── cmake/
│   ├── visionos-arm64.toolchain.cmake
│   └── visionos-simulator.toolchain.cmake
├── vcpkg/
│   └── triplets/community/
│       ├── arm64-xros.cmake
│       └── arm64-xros-simulator.cmake
├── Sources/
│   ├── OpenRCT2App/
│   │   ├── OpenRCT2App.swift           # @main, WindowGroup
│   │   ├── GameEngine.swift            # C++ interop, game loop
│   │   ├── Views/
│   │   │   └── GameView.swift          # RealityView + gestures
│   │   ├── Rendering/
│   │   │   ├── OpenRCT2Renderer.swift  # DrawableQueue pipeline
│   │   │   └── Shaders/
│   │   │       └── PaletteConvert.metal
│   │   ├── Input/
│   │   │   └── InputBridge.swift       # Gesture → CursorState
│   │   └── Audio/
│   │       └── AudioBridge.swift       # AVFoundation bridge
│   └── OpenRCT2Core/
│       ├── include/
│       │   ├── module.modulemap
│       │   ├── OpenRCT2Core.h          # Umbrella header
│       │   └── OpenRCT2Core.apinotes
│       └── visionos/
│           ├── VisionOSUiContext.h
│           └── VisionOSUiContext.cpp
├── src/openrct2/                        # (existing C++ core)
├── Resources/
│   ├── Assets.xcassets
│   └── Info.plist
├── build-visionos.sh
└── Package.swift
```

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Swift/C++ interop complexity | Medium | High | Start with minimal surface area (`GetPixelBuffer`, `GetPalette`); fall back to C shim if needed |
| DrawableQueue API changes | Low | High | Wrap in protocol; visionOS 2.0 API is stable |
| Performance (90 Hz frame pacing) | Medium | Medium | Compute shader mandatory; game tick decoupled at ~40 Hz |
| Memory pressure | Low | Medium | Single indexed buffer + one DrawableQueue (triple-buffered) |
| visionOS gaze input latency | Medium | Medium | Prototype input in M5 early; adapt gesture configuration |
| vcpkg visionOS support | Medium | Medium | Use existing iOS ports as baseline; most deps are header-only |
| Audio callback threading | Low | Low | AVAudioEngine handles buffering; use async audio queue |

---

## Success Criteria

### MVP Definition of Done

- [ ] **M1**: C++ OpenRCT2Core compiles for visionOS simulator
- [ ] **M2**: VisionOSUiContext implements IUiContext, pixel buffer accessible from Swift
- [ ] **M3**: DrawableQueue renders static test frame at 90 Hz
- [ ] **M4**: Live gameplay renders in visionOS window at ≥30fps game tick
- [ ] **M5**: Can navigate UI, select tools, place objects via look+pinch
- [ ] **M6**: Audio plays (music + sound effects) via AVFoundation
- [ ] No crashes during normal gameplay (15+ minutes)

### Ticket Summary

| Milestone | Tickets | Hours | Description |
|-----------|---------|-------|-------------|
| M1: Xcode Foundation | VOS-001→005 | 15 | Project, interop, build config |
| M2: VisionOSUiContext | VOS-010→014 | 20 | IUiContext implementation |
| M3: Metal Bridge | VOS-020→023 | 20 | DrawableQueue + compute shader |
| M4: RealityKit Display | VOS-030→033 | 15 | RealityView + live rendering |
| M5: Input | VOS-040→044 | 20 | Gaze + pinch gestures |
| M6: Audio | VOS-050→053 | 15 | AVFoundation bridge |
| **Total** | **24 tickets** | **105** | |

### Stretch Goals (Post-MVP)

- [ ] ImmersiveSpace mode (3D park viewing from above)
- [ ] Hand tracking for tool selection radial menu
- [ ] SharePlay multiplayer viewing
- [ ] Spatial audio positioning (sounds from ride locations)
- [ ] Passthrough AR mode (park on your desk)

---

## visionOS Spatial Enhancements (Post-MVP)

Beyond MVP, there are compelling ways to leverage visionOS's spatial computing capabilities while keeping the core 2D isometric rendering. These enhancements make OpenRCT2 a "good visionOS citizen" without requiring a full 3D engine rewrite.

### Level 1: Parallax UI Layers
**Effort**: ~15 hours

Separate UI elements into depth layers for subtle spatial effect:

```swift
// Game view at base depth
GameView()
    .offset(z: 0)

// Toolbars float slightly forward
ToolbarView()
    .offset(z: 20)  // 20 points toward user

// Modal dialogs even closer
if showingDialog {
    DialogView()
        .offset(z: 40)
}
```

**Effect**: Creates visual hierarchy through depth, feels native to visionOS.

### Level 2: Diorama Mode
**Effort**: ~20 hours

Display the isometric park on a tilted plane, like viewing a model train set on a table:

```swift
struct DioramaView: View {
    @EnvironmentObject var gameEngine: GameEngine
    
    var body: some View {
        RealityView { content in
            let parkPlane = ModelEntity(
                mesh: .generatePlane(width: 1.5, height: 1.0)
            )
            
            // Tilt 30° toward user, like a drafting table
            parkPlane.transform.rotation = simd_quatf(
                angle: -.pi / 6,  // -30 degrees
                axis: [1, 0, 0]
            )
            
            // Position below eye level
            parkPlane.position = [0, -0.2, -0.6]
            
            // Apply game texture
            var material = UnlitMaterial()
            material.color = .init(texture: .init(gameEngine.renderer.texture!))
            parkPlane.model?.materials = [material]
            
            content.add(parkPlane)
        }
    }
}
```

**Effect**: Park feels like a physical diorama you're looking down at. Natural fit for isometric art style.

### Level 3: God Mode (Immersive Space)
**Effort**: ~30 hours

Full immersive experience where you look down at your park from above, table-sized in your room:

```swift
// App.swift
@main
struct OpenRCT2App: App {
    @StateObject private var gameEngine = GameEngine()
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    
    var body: some Scene {
        // Standard windowed mode
        WindowGroup {
            GameView()
                .environmentObject(gameEngine)
                .toolbar {
                    Button("God Mode") {
                        Task { await openImmersiveSpace(id: "godMode") }
                    }
                }
        }
        
        // Immersive "God Mode"
        ImmersiveSpace(id: "godMode") {
            GodModeView()
                .environmentObject(gameEngine)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

struct GodModeView: View {
    @EnvironmentObject var gameEngine: GameEngine
    
    var body: some View {
        RealityView { content in
            // Large park plane, 2m × 1.5m
            let parkPlane = ModelEntity(
                mesh: .generatePlane(width: 2.0, height: 1.5)
            )
            
            // Horizontal, 1m below eye level (like a table)
            parkPlane.transform.rotation = simd_quatf(
                angle: -.pi / 2,  // Face up
                axis: [1, 0, 0]
            )
            parkPlane.position = [0, -0.8, -0.5]
            
            // Game texture
            var material = UnlitMaterial()
            material.color = .init(texture: .init(gameEngine.renderer.texture!))
            parkPlane.model?.materials = [material]
            
            content.add(parkPlane)
            
            // Optional: Add subtle "frame" around park
            let frame = ModelEntity(
                mesh: .generateBox(width: 2.1, height: 0.02, depth: 1.6)
            )
            frame.position = [0, -0.81, -0.5]
            frame.model?.materials = [SimpleMaterial(color: .brown, isMetallic: false)]
            content.add(frame)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    // Pan around the park
                    gameEngine.panCamera(delta: value.translation3D)
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    // Pinch to zoom
                    gameEngine.zoomCamera(scale: value.magnification)
                }
        )
    }
}
```

**Effect**: Your park becomes a tabletop model in your room. Walk around it, lean in to see details, gesture to interact. True spatial computing experience.

### Level 4: Spatial Audio Positioning
**Effort**: ~25 hours

Position game sounds in 3D space corresponding to their location in the park:

```swift
// When a ride makes sound, position it in 3D
func playRideSound(rideId: Int, soundId: SoundId, gamePosition: Point) {
    // Convert game coordinates to 3D space position
    let worldPos = convertGameToWorldPosition(gamePosition)
    
    // Create spatial audio source
    let audioSource = Entity()
    audioSource.position = worldPos
    audioSource.spatialAudio = SpatialAudioComponent(
        gain: -10,  // dB
        directivity: .beam(focus: 0.5)
    )
    
    // Play sound at that position
    audioSource.playAudio(soundResource)
}
```

**Effect**: Hear the rollercoaster whoosh past on your left, the carousel music from behind you at the park entrance.

### Comparison: 2D vs Spatial Modes

| Mode | View Angle | Interaction | Immersion | Effort |
|------|------------|-------------|-----------|--------|
| **MVP (Window)** | Flat, facing user | Tap/drag on window | Low | Included |
| **Parallax UI** | Flat + depth layers | Same as MVP | Low-Medium | +15 hrs |
| **Diorama** | Tilted 30° | Spatial gestures | Medium | +20 hrs |
| **God Mode** | Top-down on table | Walk around, lean in | High | +30 hrs |
| **Spatial Audio** | Any mode | Passive (audio) | Medium | +25 hrs |

### Why Not True 3D Rendering?

OpenRCT2 uses pre-rendered isometric sprites, not 3D geometry:

| Challenge | Scope |
|-----------|-------|
| No 3D models exist | Would need to create/convert every asset |
| Isometric camera hardcoded | Engine assumes fixed viewing angle |
| Lighting baked into sprites | True 3D requires real-time lighting |
| **Estimated effort** | **500-1000+ hours** |

The spatial enhancements above achieve a "3D feel" while preserving the beloved isometric art style and staying within reasonable scope.

---

## References

- [Swift C++ Interoperability Documentation](https://www.swift.org/documentation/cxx-interop/)
- [visionOS Developer Documentation](https://developer.apple.com/documentation/visionos/)
- [RealityKit TextureResource](https://developer.apple.com/documentation/realitykit/textureresource)
- [Metal Best Practices Guide](https://developer.apple.com/metal/)
- [OpenRCT2 Codebase](https://github.com/OpenRCT2/OpenRCT2)
- [Improving the usability of C libraries in Swift](https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/)
- [Creating your first visionOS app](https://developer.apple.com/documentation/visionos/creating-your-first-visionos-app)
- [Performing calculations on a GPU](https://developer.apple.com/documentation/metal/performing-calculations-on-a-gpu)
- [RealityKit - TextureResource](https://developer.apple.com/documentation/realitykit/textureresource)

---

## Archived Documentation

Previous iOS/SDL-based approach documents have been archived to:
```
docs/archive/ios-sdl-approach/
├── OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md
├── OPENRCT2_IOS_INITIATIVE.md
├── OPENRCT2_IOS_QUICKSTART.md
└── OPENRCT2_IOS_ROADMAP.md
```

These documents are retained for reference but are superseded by this native SwiftUI approach.
