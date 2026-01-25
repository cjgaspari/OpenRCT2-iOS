# OpenRCT2 iOS: Quick Start PoC Setup (Getting Something on Screen)

**Goal**: From zero to rendering OpenRCT2 on iOS display in one day.  
**Scope**: Display only, no input, minimal code.  
**Success**: Park/title screen visible at 60 FPS on iOS simulator.

---

## Prerequisites

- Xcode 14.0+
- Swift 5.7+
- iOS 26.0+ (deployment target)
- OpenRCT2 source code cloned (available in workspace)
- 2-3 hours of focused work

---

## Step 1: Create Project Structure (10 min)

```bash
cd /Users/cjgaspari/Developer/OpenRCT2-iOS

# Create directories
mkdir -p Sources/OpenRCT2Core/include
mkdir -p Sources/OpenRCT2App
mkdir -p Tests/OpenRCT2CoreTests

# Create Package.swift at root
touch Package.swift
```

---

## Step 2: Create Package.swift (5 min)

File: `/Users/cjgaspari/Developer/OpenRCT2-iOS/Package.swift`

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OpenRCT2",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "OpenRCT2Core", targets: ["OpenRCT2Core"]),
    ],
    targets: [
        .target(
            name: "OpenRCT2Core",
            dependencies: [],
            path: "Sources/OpenRCT2Core",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-fno-objc-arc", "-fvisibility=hidden"]),
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreServices"),
            ]
        ),
    ]
)
```

---

## Step 3: Create Module Map (5 min)

File: `Sources/OpenRCT2Core/include/module.modulemap`

```modulemap
module OpenRCT2Core {
  header "OpenRCT2.h"
  export *
  requires cplusplus
}
```

---

## Step 4: Create Public C Header (10 min)

File: `Sources/OpenRCT2Core/include/OpenRCT2.h`

```c
#ifndef OPENRCT2_H
#define OPENRCT2_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque context - Swift won't see internals */
typedef struct OpenRCT2ContextImpl* OpenRCT2Context;

/* Frame buffer metadata */
typedef struct {
    uint8_t* buffer;        /* Paletted 8-bit pixel data */
    uint32_t width;         /* Width in pixels */
    uint32_t height;        /* Height in pixels */
    uint32_t stride;        /* Bytes per scanline */
} FrameBufferInfo;

/* Lifecycle */
OpenRCT2Context OpenRCT2_CreateContext(void);
bool OpenRCT2_Initialize(OpenRCT2Context ctx);
void OpenRCT2_RunFrame(OpenRCT2Context ctx);
void OpenRCT2_DestroyContext(OpenRCT2Context ctx);

/* Frame access */
FrameBufferInfo OpenRCT2_GetFrameBuffer(OpenRCT2Context ctx);
const uint8_t* OpenRCT2_GetPalette(OpenRCT2Context ctx);

/* Window size */
void OpenRCT2_GetWindowSize(OpenRCT2Context ctx, uint32_t* w, uint32_t* h);

#ifdef __cplusplus
}
#endif

#endif
```

---

## Step 5: Create C++ Shim (20 min)

File: `Sources/OpenRCT2Core/OpenRCT2Shim.cpp`

This bridges the public C API to OpenRCT2's C++ internals.

```cpp
#include "OpenRCT2.h"

#include <memory>
#include <cstring>

// Forward declare OpenRCT2 classes (from actual OpenRCT2 headers)
namespace OpenRCT2 {
    struct IContext;
    std::shared_ptr<IContext> CreateContext();
}

using namespace OpenRCT2;

struct OpenRCT2ContextImpl {
    std::shared_ptr<IContext> context;
};

/* Lifecycle */

OpenRCT2Context OpenRCT2_CreateContext(void) {
    try {
        return new OpenRCT2ContextImpl();
    } catch (...) {
        return nullptr;
    }
}

bool OpenRCT2_Initialize(OpenRCT2Context ctxHandle) {
    if (!ctxHandle) return false;
    
    auto* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    try {
        // Create minimal context (no UI/Audio for PoC)
        ctx->context = CreateContext();
        
        if (!ctx->context) return false;
        
        // Initialize game subsystems
        if (!ctx->context->Initialise()) {
            return false;
        }
        
        // Launch
        ctx->context->Launch();
        return true;
        
    } catch (const std::exception& e) {
        fprintf(stderr, "Init failed: %s\n", e.what());
        return false;
    }
}

void OpenRCT2_RunFrame(OpenRCT2Context ctxHandle) {
    if (!ctxHandle) return;
    
    auto* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    if (!ctx->context) return;
    
    try {
        // Run one tick + render
        // This depends on how OpenRCT2's API is exposed
        // For now, call the main game loop step
        // ctx->context->RunFrame();
        
    } catch (...) {
        // Silently continue
    }
}

void OpenRCT2_DestroyContext(OpenRCT2Context ctxHandle) {
    if (ctxHandle) {
        auto* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
        delete ctx;
    }
}

/* Frame buffer access */

FrameBufferInfo OpenRCT2_GetFrameBuffer(OpenRCT2Context ctxHandle) {
    FrameBufferInfo info = {nullptr, 0, 0, 0};
    
    if (!ctxHandle) return info;
    
    auto* ctx = static_cast<OpenRCT2ContextImpl*>(ctxHandle);
    if (!ctx->context) return info;
    
    try {
        // Get drawing engine's pixel buffer
        // This requires accessing IDrawingEngine -> GetDrawingPixelInfo()
        // auto* rt = ctx->context->GetDrawingEngine().GetDrawingPixelInfo();
        // if (rt) {
        //     info.buffer = rt->bits;
        //     info.width = rt->width;
        //     info.height = rt->height;
        //     info.stride = rt->pitch + rt->width;
        // }
        
    } catch (...) {
        // Return empty
    }
    
    return info;
}

const uint8_t* OpenRCT2_GetPalette(OpenRCT2Context ctxHandle) {
    if (!ctxHandle) return nullptr;
    
    // Return game palette (typically gPalette)
    // extern const uint8_t gPalette[];
    // return gPalette;
    
    return nullptr;
}

void OpenRCT2_GetWindowSize(OpenRCT2Context ctxHandle, uint32_t* w, uint32_t* h) {
    if (!ctxHandle || !w || !h) return;
    
    *w = 1024;
    *h = 768;
}
```

**Note**: The shim contains TODO comments for parts that depend on OpenRCT2's internal API structure. These will be filled in after examining the actual Context.h and drawing engine headers.

---

## Step 6: Create iOS App Entry Point (15 min)

File: `Sources/OpenRCT2App/main.swift`

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

import MetalKit

class GameViewController: UIViewController {
    var metalView: MTKView!
    var gameRenderer: GameRenderer!
    var displayLink: CADisplayLink?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create Metal view
        metalView = MTKView(frame: view.bounds)
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal unavailable")
            return
        }
        metalView.device = device
        metalView.delegate = nil
        view.addSubview(metalView)
        
        // Constraints
        metalView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        // Renderer
        gameRenderer = GameRenderer()
        gameRenderer.initializeOpenRCT2()
        
        // 60 FPS loop
        displayLink = CADisplayLink(target: self, selector: #selector(updateGame))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc func updateGame() {
        // Render
        gameRenderer.draw(in: metalView)
    }
    
    deinit {
        displayLink?.invalidate()
    }
}

class GameRenderer: NSObject {
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState?
    
    private var openRCT2Context: OpaquePointer?
    
    private let width: UInt32 = 1024
    private let height: UInt32 = 768
    
    override init() {
        super.init()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal unavailable")
        }
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Command queue failed")
        }
        
        metalDevice = device
        metalCommandQueue = queue
        
        setupPipeline()
    }
    
    func setupPipeline() {
        let library = metalDevice.makeDefaultLibrary()!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Pipeline error: \(error)")
        }
    }
    
    func initializeOpenRCT2() {
        openRCT2Context = OpenRCT2_CreateContext()
        
        guard let ctx = openRCT2Context else {
            print("Failed to create context")
            return
        }
        
        let success = OpenRCT2_Initialize(ctx)
        if !success {
            print("Failed to initialize")
            OpenRCT2_DestroyContext(ctx)
            openRCT2Context = nil
            return
        }
        
        print("✅ OpenRCT2 initialized")
    }
    
    func draw(in view: MTKView) {
        guard let context = openRCT2Context,
              let drawable = view.currentDrawable else {
            return
        }
        
        // Run frame
        OpenRCT2_RunFrame(context)
        
        // Get frame buffer
        let frameInfo = OpenRCT2_GetFrameBuffer(context)
        guard let buffer = frameInfo.buffer else {
            // For now, just draw a test pattern
            drawTestPattern(drawable: drawable, view: view)
            return
        }
        
        // TODO: Convert palette buffer to RGBA and render
        // For PoC, draw test pattern to prove rendering works
        drawTestPattern(drawable: drawable, view: view)
    }
    
    private func drawTestPattern(drawable: CAMetalDrawable, view: MTKView) {
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer(),
              let renderDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    deinit {
        if let ctx = openRCT2Context {
            OpenRCT2_DestroyContext(ctx)
        }
    }
}
```

Add shaders to the Metal code:

```swift
// Add string constant with shader code
let shaderSource = """
#include <metal_stdlib>
using namespace metal;

vertex float4 vertexShader(uint vid [[vertex_id]]) {
    float2 vertices[] = {
        {-1, -1},
        { 1, -1},
        { 0,  1}
    };
    
    float4 out;
    out.xy = vertices[vid];
    out.z = 0.0;
    out.w = 1.0;
    return out;
}

fragment float4 fragmentShader() {
    return float4(0.2, 0.4, 1.0, 1.0);  // Light blue
}
"""
```

---

## Step 7: Create Minimal iOS App Target

File: `Sources/OpenRCT2App/Info.plist` (create or let Xcode generate)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OpenRCT2</string>
    <key>CFBundleIdentifier</key>
    <string>io.openrct2.ios</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenRCT2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.4.10</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIMainStoryboardFile</key>
    <string></string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>metal</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
```

---

## Step 8: Build & Test (5 min)

```bash
cd /Users/cjgaspari/Developer/OpenRCT2-iOS

# Build
swift build

# Or open in Xcode
open Package.swift
```

In Xcode:
1. Select "iPhone 17 Pro" simulator
2. Product → Build (Cmd+B)
3. Product → Run (Cmd+R)

**Expected**: Blue triangle renders on screen, 60 FPS

---

## Step 9: Add Real OpenRCT2 Rendering (30 min)

Once the basic app runs, add palette → RGBA conversion and real frame buffer display:

```swift
// In GameRenderer.draw()

// Get palette
guard let palette = OpenRCT2_GetPalette(context) else {
    return
}

// Allocate RGBA buffer
let rgbaSize = Int(width * height * 4)
let rgbaBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: rgbaSize, alignment: 4)
defer { rgbaBuffer.deallocate() }

// Convert palette to RGBA
convertPaletteToRGBA(
    from: frameInfo.buffer,
    palette: palette,
    width: frameInfo.width,
    height: frameInfo.height,
    stride: frameInfo.stride,
    to: rgbaBuffer.baseAddress!
)

// Create Metal texture
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm,
    width: Int(frameInfo.width),
    height: Int(frameInfo.height),
    mipmapped: false
)

let texture = metalDevice.makeTexture(descriptor: textureDescriptor)!
texture.replace(
    region: MTLRegionMake2D(0, 0, Int(frameInfo.width), Int(frameInfo.height)),
    mipmapLevel: 0,
    withBytes: rgbaBuffer.baseAddress!,
    bytesPerRow: Int(frameInfo.width) * 4
)

// Render textured quad
// (Use texture in fragment shader)
```

---

## Step 10: Verify Success

When running:

✅ App launches without crash  
✅ "OpenRCT2 initialized" prints to console  
✅ Solid color or test pattern renders on screen  
✅ 60 FPS (check Console for frame timing)  
✅ App stays running for >30 seconds

---

## Troubleshooting

### Linker Errors
- Check that OpenRCT2's C++ headers are accessible
- Verify `module.modulemap` is in correct path
- May need to link against pre-built OpenRCT2 framework

### Metal API Crashes
- Ensure `MTKView.device` is set before drawing
- Verify shader source code doesn't have syntax errors
- Check that render pass descriptor is valid

### OpenRCT2 Init Fails
- Check that data files are accessible
- May need headless mode until asset bundling is ready
- Log actual error message (catch exception in shim)

---

## What's Next (After PoC Works)

1. **Real Frame Buffer**: Replace test pattern with actual OpenRCT2 frame
2. **Input**: Add touch handlers (later phase)
3. **Assets**: Bundle RCT2 data files (later phase)
4. **Optimization**: Profile & optimize (later phase)

---

## File Checklist

```
OpenRCT2-iOS/
├── Package.swift                           ✓
├── Sources/
│   ├── OpenRCT2Core/
│   │   ├── include/
│   │   │   ├── module.modulemap           ✓
│   │   │   └── OpenRCT2.h                 ✓
│   │   └── OpenRCT2Shim.cpp               ✓
│   └── OpenRCT2App/
│       ├── main.swift                     ✓
│       └── Info.plist                     ✓
└── Tests/
    └── [optional for PoC]
```

---

## Time Estimate

| Task | Time |
|------|------|
| Project structure | 10 min |
| Module map & headers | 10 min |
| Package.swift | 5 min |
| Shim layer | 20 min |
| iOS app shell | 15 min |
| Build & test | 5 min |
| **TOTAL** | ~60 min |

**Reality**: 90 minutes with debugging.

---

## Success Definition

**You'll know it worked when:**

1. App runs on iOS simulator without crashing
2. Blue (or any solid color) renders on screen
3. Frame buffer metrics print to console
4. Maintains 60 FPS for >1 minute
5. No memory leaks (check Instruments)

**At this point, you have a working foundation to add:**
- Real frame buffer rendering
- Touch input
- Asset loading
- Performance optimization

---

**Status**: Ready to execute  
**Difficulty**: Medium (requires C++/Swift bridge knowledge)  
**Risk**: Low (Metal/app code is boilerplate; OpenRCT2 linkage is the variable)
