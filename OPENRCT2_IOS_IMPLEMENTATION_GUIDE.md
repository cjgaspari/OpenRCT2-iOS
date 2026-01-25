# OpenRCT2 iOS: Implementation Technical Guide

This document provides concrete code examples and detailed implementation steps for bringing OpenRCT2 to iOS.

---

## Part 1: Swift/C Interoperability Setup

### 1.1 Module Map for OpenRCT2

File: `Sources/OpenRCT2Core/include/module.modulemap`

```modulemap
module OpenRCT2Core {
  umbrella header "OpenRCT2.h"
  
  // Expose necessary submodules
  explicit module OpenRCT2 {
    header "OpenRCT2.h"
    export *
  }
  
  requires cplusplus
}
```

### 1.2 API Notes for C→Swift Type Mapping

File: `Sources/OpenRCT2Core/include/OpenRCT2.apinotes`

```yaml
---
Name: OpenRCT2Core

Tags:
  # Opaque context handle - import as a Swift class with automatic cleanup
  - Name: OpenRCT2ContextImpl
    SwiftImportAs: reference
    SwiftReleaseOp: OpenRCT2_DestroyContext
    # No retain op - one-way ownership

Typedefs:
  # Frame buffer info structure
  - Name: FrameBufferInfo
    SwiftWrapper: struct

Functions:
  # Initialization functions - return with ownership
  - Name: OpenRCT2_CreateContext
    SwiftReturnOwnership: retained
    SwiftName: OpenRCT2Context.create()
  
  - Name: OpenRCT2_Initialize
    SwiftName: OpenRCT2Context.initialize(self:)
  
  # Frame operations
  - Name: OpenRCT2_RunFrame
    SwiftName: OpenRCT2Context.runFrame(self:)
  
  - Name: OpenRCT2_GetFrameBuffer
    SwiftName: OpenRCT2Context.getFrameBuffer(self:info:)
  
  # Cleanup - explicitly marked
  - Name: OpenRCT2_DestroyContext
    SwiftName: OpenRCT2Context.destroy(self:)

Globals:
  # Expose version as property-like constant
  - Name: OPENRCT2_VERSION_STRING
    SwiftName: OpenRCT2.versionString
```

### 1.3 OpenRCT2 Public C Header

File: `Sources/OpenRCT2Core/include/OpenRCT2.h`

```c
/*
 * OpenRCT2 iOS C Interface
 * Swift-accessible C API for OpenRCT2 game engine
 */

#ifndef OPENRCT2_H
#define OPENRCT2_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Version & Information
 * ============================================================================ */

#define OPENRCT2_VERSION_MAJOR 0
#define OPENRCT2_VERSION_MINOR 4
#define OPENRCT2_VERSION_PATCH 10

extern const char* OPENRCT2_VERSION_STRING;
extern const char* OpenRCT2_GetVersionString(void);

/* ============================================================================
 * Context Lifecycle
 * ============================================================================ */

// Opaque context handle
typedef struct OpenRCT2ContextImpl* OpenRCT2Context;

/**
 * Create a new OpenRCT2 context.
 * Must be passed to OpenRCT2_Initialize before use.
 * 
 * @returns
 * A new context instance. Returns NULL on failure.
 * This value has @ref ReturnedWithOwnership.
 */
OpenRCT2Context OpenRCT2_CreateContext(void);

/**
 * Initialize the OpenRCT2 context for iOS.
 * This loads assets, initializes subsystems, etc.
 * 
 * @param ctx The context to initialize (from OpenRCT2_CreateContext)
 * @returns true if initialization succeeded, false otherwise
 */
bool OpenRCT2_Initialize(OpenRCT2Context ctx);

/**
 * Run one frame of the game loop (tick + render).
 * Call this every 16ms (60 FPS) or 33ms (30 FPS).
 * 
 * @param ctx The context to run
 * @param deltaTimeMS Time elapsed since last frame in milliseconds
 */
void OpenRCT2_RunFrame(OpenRCT2Context ctx, uint32_t deltaTimeMS);

/**
 * Destroy a context and release all resources.
 * 
 * @param ctx The context to destroy
 * This is the only place where ownership is transferred back to caller.
 */
void OpenRCT2_DestroyContext(OpenRCT2Context ctx);

/* ============================================================================
 * Frame Buffer Access
 * ============================================================================ */

typedef struct {
    uint8_t* buffer;        // Pointer to pixel data (paletted 8-bit)
    uint32_t width;         // Width in pixels
    uint32_t height;        // Height in pixels
    uint32_t stride;        // Bytes per scanline
} FrameBufferInfo;

/**
 * Get the current frame buffer for rendering.
 * The buffer contains paletted 8-bit pixel data.
 * To display: convert palette indices to RGBA and upload to screen.
 * 
 * @param ctx The context
 * @return FrameBufferInfo structure with buffer pointer and dimensions
 */
FrameBufferInfo OpenRCT2_GetFrameBuffer(OpenRCT2Context ctx);

/**
 * Get the game palette (256 × 3 bytes: R, G, B triplets).
 * Use this to convert 8-bit palette indices to RGB colors.
 * 
 * @param ctx The context
 * @return Pointer to 256×3=768 bytes of palette data (R, G, B)
 */
const uint8_t* OpenRCT2_GetPalette(OpenRCT2Context ctx);

/* ============================================================================
 * Input Handling
 * ============================================================================ */

typedef enum {
    OPENRCT2_INPUT_TYPE_MOUSE_MOVE,
    OPENRCT2_INPUT_TYPE_MOUSE_LEFT_DOWN,
    OPENRCT2_INPUT_TYPE_MOUSE_LEFT_UP,
    OPENRCT2_INPUT_TYPE_MOUSE_RIGHT_DOWN,
    OPENRCT2_INPUT_TYPE_MOUSE_RIGHT_UP,
    OPENRCT2_INPUT_TYPE_MOUSE_WHEEL,
} OpenRCT2InputType;

/**
 * Submit mouse input to the game.
 * 
 * @param ctx The context
 * @param type The input type
 * @param x X coordinate in game pixels
 * @param y Y coordinate in game pixels
 * @param wheelDelta Wheel delta (for scroll events)
 */
void OpenRCT2_SubmitInput(
    OpenRCT2Context ctx,
    OpenRCT2InputType type,
    int32_t x,
    int32_t y,
    int32_t wheelDelta);

/* ============================================================================
 * Configuration
 * ============================================================================ */

/**
 * Set the game window size (game coordinates, not screen pixels).
 * Default is 1024×768.
 * 
 * @param ctx The context
 * @param width Width in game pixels
 * @param height Height in game pixels
 */
void OpenRCT2_SetWindowSize(OpenRCT2Context ctx, uint32_t width, uint32_t height);

/**
 * Get the game window size.
 * 
 * @param ctx The context
 * @param outWidth Output: width in game pixels
 * @param outHeight Output: height in game pixels
 */
void OpenRCT2_GetWindowSize(OpenRCT2Context ctx, uint32_t* outWidth, uint32_t* outHeight);

/**
 * Set the path to RCT2 data directory.
 * Must be called before Initialize().
 * 
 * @param ctx The context
 * @param path Path to data directory (e.g., "/var/mobile/Documents/openrct2-data/")
 */
void OpenRCT2_SetDataPath(OpenRCT2Context ctx, const char* path);

#ifdef __cplusplus
}
#endif

#endif // OPENRCT2_H
```

---

## Part 2: C++ Implementation Shim

File: `Sources/OpenRCT2Core/OpenRCT2Shim.cpp`

This file bridges from the public C API to the internal C++ OpenRCT2 classes.

```cpp
#include "OpenRCT2.h"

#include <openrct2/Context.h>
#include <openrct2/ui/UiContext.h>
#include <openrct2/drawing/IDrawingEngine.h>
#include <openrct2/Version.h>

#include <cstring>
#include <memory>

using namespace OpenRCT2;

/* ============================================================================
 * Context Wrapper
 * ============================================================================ */

struct OpenRCT2ContextImpl {
    std::shared_ptr<IContext> context;
    uint8_t* lastFrameBuffer = nullptr;
    FrameBufferInfo lastFrameInfo = {};
};

/* ============================================================================
 * Version Information
 * ============================================================================ */

const char* OPENRCT2_VERSION_STRING = OPENRCT2_VERSION;

const char* OpenRCT2_GetVersionString(void) {
    return OPENRCT2_VERSION_STRING;
}

/* ============================================================================
 * Lifecycle Functions
 * ============================================================================ */

OpenRCT2Context OpenRCT2_CreateContext(void) {
    try {
        auto ctx = new OpenRCT2ContextImpl();
        // Don't create the actual OpenRCT2 context yet; wait for Initialize()
        return ctx;
    } catch (...) {
        return nullptr;
    }
}

bool OpenRCT2_Initialize(OpenRCT2Context ctxHandle) {
    if (ctxHandle == nullptr) {
        return false;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    try {
        // Create the main context (this is expensive)
        auto env = CreatePlatformEnvironment();
        auto audioContext = CreateDummyAudioContext();  // Silence for now
        auto uiContext = CreateUiContext(*env);         // Will use headless mode for iOS
        
        ctx->context = CreateContext(
            std::move(env),
            std::move(audioContext),
            std::move(uiContext)
        );
        
        // Initialize OpenRCT2 subsystems
        if (!ctx->context->Initialise()) {
            return false;
        }
        
        // Launch into the game
        ctx->context->Launch();
        
        return true;
    } catch (const std::exception& e) {
        // Log error: should implement proper logging
        fprintf(stderr, "OpenRCT2 initialization failed: %s\n", e.what());
        return false;
    } catch (...) {
        fprintf(stderr, "OpenRCT2 initialization failed with unknown exception\n");
        return false;
    }
}

void OpenRCT2_RunFrame(OpenRCT2Context ctxHandle, uint32_t deltaTimeMS) {
    if (ctxHandle == nullptr) {
        return;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return;
    }
    
    try {
        // Run one game frame
        ctx->context->RunOpenRCT2(0, nullptr);  // Simpler version that just ticks+renders
        
    } catch (const std::exception& e) {
        fprintf(stderr, "Frame execution error: %s\n", e.what());
    } catch (...) {
        fprintf(stderr, "Frame execution error: unknown exception\n");
    }
}

void OpenRCT2_DestroyContext(OpenRCT2Context ctxHandle) {
    if (ctxHandle == nullptr) {
        return;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    try {
        ctx->context.reset();
        delete ctx;
    } catch (...) {
        // Best effort cleanup
        delete ctx;
    }
}

/* ============================================================================
 * Frame Buffer Access
 * ============================================================================ */

FrameBufferInfo OpenRCT2_GetFrameBuffer(OpenRCT2Context ctxHandle) {
    FrameBufferInfo info = {};
    
    if (ctxHandle == nullptr) {
        return info;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return info;
    }
    
    try {
        // Get the drawing engine's pixel buffer
        auto* drawingEngine = &ctx->context->GetDrawingEngine();
        if (drawingEngine == nullptr) {
            return info;
        }
        
        auto* rt = drawingEngine->GetDrawingPixelInfo();
        if (rt == nullptr) {
            return info;
        }
        
        info.buffer = rt->bits;
        info.width = rt->width;
        info.height = rt->height;
        info.stride = rt->pitch + rt->width;  // pitch is offset, stride is full line
        
        return info;
    } catch (...) {
        return info;
    }
}

const uint8_t* OpenRCT2_GetPalette(OpenRCT2Context ctxHandle) {
    if (ctxHandle == nullptr) {
        return nullptr;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return nullptr;
    }
    
    try {
        // Return the current game palette
        // This is typically stored in gPalette in the OpenRCT2 core
        // You may need to expose this via a proper getter
        return reinterpret_cast<const uint8_t*>(gPalette);
    } catch (...) {
        return nullptr;
    }
}

/* ============================================================================
 * Input Handling
 * ============================================================================ */

void OpenRCT2_SubmitInput(
    OpenRCT2Context ctxHandle,
    OpenRCT2InputType type,
    int32_t x,
    int32_t y,
    int32_t wheelDelta) {
    
    if (ctxHandle == nullptr) {
        return;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return;
    }
    
    try {
        // Convert OpenRCT2InputType to SDL_Event or internal input events
        // This depends on how OpenRCT2's input system is architectured
        
        InputEvent event = {};
        event.deviceKind = InputDeviceKind::mouse;
        
        switch (type) {
            case OPENRCT2_INPUT_TYPE_MOUSE_MOVE:
                event.state = InputEventState::active;
                break;
            case OPENRCT2_INPUT_TYPE_MOUSE_LEFT_DOWN:
                event.state = InputEventState::down;
                event.button = SDL_BUTTON_LEFT;
                break;
            case OPENRCT2_INPUT_TYPE_MOUSE_LEFT_UP:
                event.state = InputEventState::release;
                event.button = SDL_BUTTON_LEFT;
                break;
            case OPENRCT2_INPUT_TYPE_MOUSE_RIGHT_DOWN:
                event.state = InputEventState::down;
                event.button = SDL_BUTTON_RIGHT;
                break;
            case OPENRCT2_INPUT_TYPE_MOUSE_RIGHT_UP:
                event.state = InputEventState::release;
                event.button = SDL_BUTTON_RIGHT;
                break;
            default:
                return;
        }
        
        // Submit to input manager
        // auto& inputMgr = GetInputManager();
        // inputMgr.queueInputEvent(event);
        
    } catch (...) {
        // Debug: log input error
    }
}

/* ============================================================================
 * Configuration
 * ============================================================================ */

void OpenRCT2_SetWindowSize(OpenRCT2Context ctxHandle, uint32_t width, uint32_t height) {
    if (ctxHandle == nullptr) {
        return;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return;
    }
    
    try {
        // Resize the game's internal drawing engine
        ctx->context->GetUiContext().ResizeWindow(width, height);
    } catch (...) {
        // Ignore
    }
}

void OpenRCT2_GetWindowSize(OpenRCT2Context ctxHandle, uint32_t* outWidth, uint32_t* outHeight) {
    if (ctxHandle == nullptr || outWidth == nullptr || outHeight == nullptr) {
        return;
    }
    
    OpenRCT2ContextImpl* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    
    if (ctx->context == nullptr) {
        return;
    }
    
    try {
        auto& uiContext = ctx->context->GetUiContext();
        *outWidth = uiContext.GetWidth();
        *outHeight = uiContext.GetHeight();
    } catch (...) {
        *outWidth = 1024;
        *outHeight = 768;
    }
}

void OpenRCT2_SetDataPath(OpenRCT2Context ctxHandle, const char* path) {
    if (ctxHandle == nullptr || path == nullptr) {
        return;
    }
    
    // This should be called on the environment before context creation
    // For now, just a placeholder
    // Implementation depends on how environment paths are set
}
```

---

## Part 3: Swift iOS App Implementation

### 3.1 Game Renderer

File: `Sources/OpenRCT2App/GameRenderer.swift`

```swift
import MetalKit
import simd

class GameRenderer: NSObject, MTKViewDelegate {
    private var metalDevice: MTLDevice
    private var metalCommandQueue: MTLCommandQueue
    private var renderPipeline: MTLRenderPipelineState?
    
    private var colorTexture: MTLTexture?
    private var textureBuffer: UnsafeMutableRawPointer?
    
    private var openRCT2Context: OpaquePointer?
    
    private let width: UInt32 = 1024
    private let height: UInt32 = 768
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not available on this device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        
        self.metalDevice = device
        self.metalCommandQueue = commandQueue
        
        super.init()
        setupRenderPipeline()
    }
    
    func setupRenderPipeline() {
        // TODO: Create Metal render pipeline for displaying paletted texture
        // This would include a simple vertex/fragment shader pair
    }
    
    func initializeOpenRCT2() {
        // Create OpenRCT2 context
        openRCT2Context = OpenRCT2_CreateContext()
        
        guard let ctx = openRCT2Context else {
            print("Failed to create OpenRCT2 context")
            return
        }
        
        // Initialize
        let success = OpenRCT2_Initialize(ctx)
        if !success {
            print("Failed to initialize OpenRCT2")
            OpenRCT2_DestroyContext(ctx)
            openRCT2Context = nil
            return
        }
        
        print("OpenRCT2 initialized successfully")
    }
    
    func draw(in view: MTKView) {
        guard let context = openRCT2Context else {
            return
        }
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        // Run one game frame
        OpenRCT2_RunFrame(context, 16)  // 16 ms = 60 FPS
        
        // Get frame buffer from OpenRCT2
        let frameInfo = OpenRCT2_GetFrameBuffer(context)
        guard frameInfo.buffer != nil else {
            return
        }
        
        // Get palette
        let palette = OpenRCT2_GetPalette(context)
        guard let palette = palette else {
            return
        }
        
        // Convert paletted buffer to RGBA texture
        updateTexture(
            palette8: frameInfo.buffer,
            palette: palette,
            width: frameInfo.width,
            height: frameInfo.height,
            stride: frameInfo.stride
        )
        
        // Render to screen
        renderToScreen(drawable: drawable, view: view)
    }
    
    private func updateTexture(
        palette8: UnsafeMutableRawPointer?,
        palette: UnsafeRawPointer,
        width: UInt32,
        height: UInt32,
        stride: UInt32
    ) {
        // Allocate RGBA buffer if needed
        let rgbaBufferSize = Int(width * height * 4)
        if textureBuffer == nil {
            textureBuffer = malloc(rgbaBufferSize)
        }
        
        guard let rgbaBuffer = textureBuffer else {
            return
        }
        
        // Convert palette indices to RGBA
        convertPaletteToRGBA(
            paletted: palette8,
            palette: palette,
            width: width,
            height: height,
            stride: stride,
            outRGBA: rgbaBuffer
        )
        
        // Update Metal texture
        createOrUpdateTexture(
            data: rgbaBuffer,
            width: width,
            height: height
        )
    }
    
    private func convertPaletteToRGBA(
        paletted: UnsafeMutableRawPointer?,
        palette: UnsafeRawPointer,
        width: UInt32,
        height: UInt32,
        stride: UInt32,
        outRGBA: UnsafeMutableRawPointer
    ) {
        guard let palettedBuffer = paletted else {
            return
        }
        
        let paletteBytes = palette.assumingMemoryBound(to: UInt8.self)
        let indexBuffer = palettedBuffer.assumingMemoryBound(to: UInt8.self)
        let rgbaBuffer = outRGBA.assumingMemoryBound(to: UInt32.self)
        
        for y in 0..<height {
            for x in 0..<width {
                let indexOffset = Int(y * stride + x)
                let paletteIndex = Int(indexBuffer[indexOffset])
                
                let r = paletteBytes[paletteIndex * 3]
                let g = paletteBytes[paletteIndex * 3 + 1]
                let b = paletteBytes[paletteIndex * 3 + 2]
                let a: UInt8 = 255
                
                let rgbaOffset = Int(y * width + x)
                rgbaBuffer[rgbaOffset] = UInt32(r) |
                                          (UInt32(g) << 8) |
                                          (UInt32(b) << 16) |
                                          (UInt32(a) << 24)
            }
        }
    }
    
    private func createOrUpdateTexture(
        data: UnsafeMutableRawPointer,
        width: UInt32,
        height: UInt32
    ) {
        // TODO: Implement Metal texture creation/update
        // This would:
        // 1. Create MTLTexture if not exists
        // 2. Update texture contents from data buffer
        // 3. Store for rendering
    }
    
    private func renderToScreen(drawable: CAMetalDrawable, view: MTKView) {
        // TODO: Implement Metal rendering to drawable
    }
    
    deinit {
        if let context = openRCT2Context {
            OpenRCT2_DestroyContext(context)
        }
        
        if let buffer = textureBuffer {
            free(buffer)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
}
```

### 3.2 View Controller

File: `Sources/OpenRCT2App/GameViewController.swift`

```swift
import UIKit
import MetalKit

class GameViewController: UIViewController {
    var metalView: MTKView!
    var gameRenderer: GameRenderer!
    var displayLink: CADisplayLink?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create Metal view
        metalView = MTKView(frame: view.bounds)
        if let device = MTLCreateSystemDefaultDevice() {
            metalView.device = device
        } else {
            print("Metal is not available")
            return
        }
        
        metalView.delegate = nil  // We'll handle rendering manually
        view.addSubview(metalView)
        
        // Setup Auto Layout
        metalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        // Create and initialize game renderer
        gameRenderer = GameRenderer()
        gameRenderer.initializeOpenRCT2()
        
        // Setup display link for 60 FPS rendering
        setupDisplayLink()
        
        // Setup touch input
        setupTouchHandling()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateGame)
        )
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc func updateGame(displayLink: CADisplayLink) {
        // Use the Metal view to render
        if let drawable = metalView.currentDrawable {
            gameRenderer.draw(in: metalView)
        }
    }
    
    private func setupTouchHandling() {
        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        view.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let gameCoords = screenToGameCoordinates(location)
        
        // Submit left mouse click
        // (Detailed input handling would go here)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: view)
        let gameCoords = screenToGameCoordinates(location)
        
        switch gesture.state {
        case .began:
            // Mouse down
            break
        case .changed:
            // Mouse moved
            break
        case .ended, .cancelled:
            // Mouse up
            break
        default:
            break
        }
    }
    
    private func screenToGameCoordinates(_ screenPoint: CGPoint) -> CGPoint {
        // Scale from screen coordinates to game coordinates
        let scale = view.bounds.width / 1024  // Game is 1024 pixels wide
        return CGPoint(
            x: screenPoint.x / scale,
            y: screenPoint.y / scale
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
    }
}
```

### 3.3 App Delegate & Entry Point

File: `Sources/OpenRCT2App/AppDelegate.swift`

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
```

---

## Part 4: Package.swift Configuration

File: `Package.swift`

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OpenRCT2",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "OpenRCT2Core", targets: ["OpenRCT2Core"]),
        .app(name: "OpenRCT2", targets: ["OpenRCT2App"]),
    ],
    targets: [
        // C wrapper target for OpenRCT2 game engine
        .target(
            name: "OpenRCT2Core",
            dependencies: [],
            path: "Sources/OpenRCT2Core",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags([
                    "-fno-objc-arc",
                    "-fvisibility=hidden",
                    "-fvisibility-inlines-hidden",
                ]),
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreServices"),
            ]
        ),
        
        // iOS app targets
        .target(
            name: "OpenRCT2App",
            dependencies: ["OpenRCT2Core"],
            path: "Sources/OpenRCT2App",
            resources: [
                .process("Resources/Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"]),
            ]
        ),
    ]
)
```

---

## Part 5: Key Linking Issues & Solutions

### Issue 1: C++ Symbol Mangling

**Problem**: C++ OpenRCT2 code uses name mangling; C declarations won't link.

**Solution**: Use `extern "C"` wrapper in shim:

```cpp
extern "C" {
    // C declarations here
    
    // This function uses C++ internally
    void OpenRCT2_RunFrame(OpenRCT2Context ctx, uint32_t deltaTimeMS) {
        // Call C++ OpenRCT2 code
        auto* c = static_cast<OpenRCT2ContextImpl*>(ctx);
        c->context->RunOpenRCT2(0, nullptr);  // C++ method call
    }
}
```

### Issue 2: CMake + SPM Integration

**Problem**: OpenRCT2 uses CMake; SPM prefers its own build system.

**Solutions**:

**Option A (Recommended for MVP)**: Pre-build as framework
```bash
# Build once for iOS
cmake -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
  -DIOS_PLATFORM=OS \
  ../OpenRCT2

cmake --build .
xcodebuild -project openrct2.xcodeproj \
  -target openrct2 \
  -configuration Release \
  -derivedDataPath DerivedData

# Package as xcframework
xcodebuild -create-xcframework \
  -library DerivedData/Build/Products/Release-iphoneos/libopenrct2.a \
  -headers Sources/openrct2/include \
  -output OpenRCT2Core.xcframework
```

**Option B (Advanced)**: SPM build plugins - see [SPM plugins documentation](https://github.com/apple/swift-package-manager/blob/main/Documentation/Plugins.md).

### Issue 3: SDL2 on iOS

**Problem**: SDL2 iOS support is minimal in standard distribution.

**Solutions**:

```swift
// In Package.swift, link SDL2 if available
.target(
    name: "OpenRCT2Core",
    linkerSettings: [
        .linkedLibrary("SDL2"),  // If pre-installed
        // OR
        .unsafeFlags(["-L/path/to/SDL2/lib", "-lSDL2"]),
    ]
)
```

**Or** build SDL2 yourself for iOS and include as binary target.

---

## Part 6: Testing & Debugging

### Unit Test Example

File: `Tests/OpenRCT2CoreTests/InitializationTests.swift`

```swift
import XCTest
import OpenRCT2Core

class InitializationTests: XCTestCase {
    func testContextCreation() {
        let context = OpenRCT2_CreateContext()
        XCTAssertNotNil(context, "Failed to create OpenRCT2 context")
        OpenRCT2_DestroyContext(context)
    }
    
    func testInitialization() {
        let context = OpenRCT2_CreateContext()
        defer { OpenRCT2_DestroyContext(context) }
        
        let success = OpenRCT2_Initialize(context)
        XCTAssertTrue(success, "Failed to initialize OpenRCT2")
    }
    
    func testFrameExecution() {
        let context = OpenRCT2_CreateContext()
        defer { OpenRCT2_DestroyContext(context) }
        
        XCTAssertTrue(OpenRCT2_Initialize(context))
        
        // Run 10 frames - should not crash
        for _ in 0..<10 {
            OpenRCT2_RunFrame(context, 16)
        }
        
        let frameInfo = OpenRCT2_GetFrameBuffer(context)
        XCTAssertNotNil(frameInfo.buffer, "Frame buffer is NULL")
        XCTAssertGreaterThan(frameInfo.width, 0)
        XCTAssertGreaterThan(frameInfo.height, 0)
    }
}
```

### Debugging with Instruments

1. Profile with **Time Profiler** to find CPU bottlenecks
2. Use **Metal Debugger** for GPU analysis (once Metal path added)
3. Check **Memory** tab for leaks in C++ wrapper

---

## Part 7: Performance Optimization Checklist

### Phase 1 (MVP)
- [ ] Basic rendering works
- [ ] No crashes for 5+ minutes
- [ ] FPS >= 30 on iPhone 12

### Phase 2
- [ ] FPS = 60 on iPhone 12
- [ ] Dirty rectangle optimization active

### Phase 3 (Optional)
- [ ] SIMD palette conversion
- [ ] Metal rendering path
- [ ] Battery test: 3+ hours play time

---

## References

1. [Swift C Interop Blog](https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/)
2. [Module Maps docs](https://clang.llvm.org/docs/Modules.html)
3. [API Notes docs](https://clang.llvm.org/docs/APINotes.html)
4. [SPM Package struct](https://swiftpackageindex.com/)
5. [Metal API docs](https://developer.apple.com/documentation/metal)
6. [Xcode debugging](https://developer.apple.com/xcode/)
