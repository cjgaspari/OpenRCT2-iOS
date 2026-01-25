# OpenRCT2 visionOS 26 Spec (Migration) — RealityKit Panel → Metal-Backed Window
**Purpose:** Migrate from your current RealityKit implementation to a **Metal-backed window renderer** while keeping **as much existing work as possible** (especially the C++↔Swift bridge and input/event logic).

This guide assumes:
- You already have a working C ABI bridge (or nearly working) from C++ to Swift
- You already mapped input concepts (tap/drag/scroll/right-click) to OpenRCT2-style mouse events
- The remaining pain is RealityKit rendering reliability and pixel-perfect presentation

---

## 1. What You Keep vs What Changes

### 1.1 Keep (do NOT redo)
✅ C++ core build system and library packaging (XCFramework/static lib)  
✅ C ABI functions:
- `rct2_init`, `rct2_update`, `rct2_get_frame`
- mouse move/button/wheel
✅ Framebuffer contract:
- width/height/stride + pixel format + pointer
✅ Your higher-level input mapping decisions:
- what gesture means “right click”
- scroll mapping
- drag behavior

### 1.2 Replace
🔁 RealityKit view + entity + material pipeline  
→ with  
✅ A single **CAMetalLayer-backed view** that:
- uploads framebuffer → `MTLTexture`
- draws a fullscreen textured triangle
- uses a **nearest** sampler

### 1.3 Payoff
- Fewer moving parts
- Pixel-perfect control (true nearest sampling)
- More deterministic performance
- Simpler coordinate mapping in a window app

---

## 2. Target Architecture (Window App)

```
SwiftUI WindowGroup
   └─ UIViewRepresentable
       └─ MetalLayerView (UIView + CAMetalLayer)
            ├─ calls rct2_update(dt)
            ├─ calls rct2_get_frame()
            ├─ uploads pixels → MTLTexture
            └─ renders quad with nearest sampler
```

RealityKit is removed from the rendering path.

---

## 3. Implementation Steps (Minimal Disruption)

### Step 0 — Freeze the Bridge Contract
Before changing rendering:
- Lock pixel format to **BGRA8888** if possible
- Ensure stride is correct (bytes per row)
- Ensure framebuffer pointer stays valid until the next frame call

**Important**
If you currently produce RGBA, switch it back to BGRA, as that reduces friction for Metal.

---

### Step 1 — Add a MetalLayerView (CAMetalLayer)
Create a UIKit view for rendering:

```swift
import UIKit
import Metal
import QuartzCore

final class MetalLayerView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    private let device = MTLCreateSystemDefaultDevice()!
    private let commandQueue: MTLCommandQueue

    private var pipeline: MTLRenderPipelineState!
    private var texture: MTLTexture?

    // timing
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        commandQueue = device.makeCommandQueue()!
        super.init(frame: frame)
        setupMetal()
        startLoop()
    }

    required init?(coder: NSCoder) { fatalError() }
}
```

Metal setup:
```swift
private func setupMetal() {
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true

    let lib = device.makeDefaultLibrary()!
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = lib.makeFunction(name: "vertex_main")
    desc.fragmentFunction = lib.makeFunction(name: "fragment_main")
    desc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat
    pipeline = try! device.makeRenderPipelineState(descriptor: desc)
}
```

---

### Step 2 — Wire SwiftUI Hosting
Replace your `RealityView` with `UIViewRepresentable`:

```swift
import SwiftUI

struct GameView: UIViewRepresentable {
    func makeUIView(context: Context) -> MetalLayerView { MetalLayerView() }
    func updateUIView(_ uiView: MetalLayerView, context: Context) {}
}
```

In `App`:
```swift
@main
struct OpenRCT2VisionApp: App {
    var body: some Scene {
        WindowGroup { GameView() }
        .defaultSize(width: 1280, height: 800)
    }
}
```

---

### Step 3 — Shaders with Nearest Sampler
`Shaders.metal`:

```metal
#include <metal_stdlib>
using namespace metal;

// Fullscreen triangle. No vertex buffers.
vertex float4 vertex_main(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    return float4(pos[vid], 0, 1);
}

// Nearest-neighbor sampler for crisp pixels.
fragment float4 fragment_main(float4 position [[position]],
                              texture2d<float> frameTex [[texture(0)]]) {
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    float2 uv = position.xy * 0.5 + 0.5;
    return frameTex.sample(s, uv);
}
```

---

### Step 4 — Upload OpenRCT2 Framebuffer → Metal Texture
Texture creation:
```swift
private func ensureTexture(width: Int, height: Int) {
    if texture == nil || texture!.width != width || texture!.height != height {
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        d.usage = [.shaderRead]
        texture = device.makeTexture(descriptor: d)
    }
}
```

Upload:
```swift
private func upload(frame: RCT2_Frame) {
    ensureTexture(width: frame.width, height: frame.height)
    texture!.replace(
        region: MTLRegionMake2D(0, 0, frame.width, frame.height),
        mipmapLevel: 0,
        withBytes: frame.pixels,
        bytesPerRow: frame.strideBytes
    )
}
```

If your framebuffer is RGBA8888, either:
- change Metal texture format to `.rgba8Unorm` and shaders unchanged, or
- swizzle in the shader (slower) or during upload (slower)

Prefer aligning to BGRA in OpenRCT2 for migration simplicity.

---

### Step 5 — Draw Loop (Reuse Existing Update Cadence)
If you already had a tick loop for RealityKit, keep it.
Otherwise:

```swift
private func startLoop() {
    displayLink = CADisplayLink(target: self, selector: #selector(tick))
    displayLink?.add(to: .main, forMode: .common)
}

@objc private func tick() {
    let now = CACurrentMediaTime()
    let dt = Float(now - lastTime)
    lastTime = now

    rct2_update(dt)
    let frame = rct2_get_frame()
    upload(frame: frame)
    draw()
}
```

Draw:
```swift
private func draw() {
    guard let drawable = metalLayer.nextDrawable(),
          let cb = commandQueue.makeCommandBuffer(),
          let tex = texture else { return }

    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store

    let enc = cb.makeRenderCommandEncoder(descriptor: pass)!
    enc.setRenderPipelineState(pipeline)
    enc.setFragmentTexture(tex, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    enc.endEncoding()

    cb.present(drawable)
    cb.commit()
}
```

---

## 4. Input Migration (RealityKit → Window Coordinates)

### 4.1 What changes
RealityKit required raycasting to the plane.
In a window Metal view, you can use direct view coordinates.

### 4.2 What stays the same
Your conceptual mapping:
- tap → left click
- drag → left drag
- scroll → wheel
- long press / modifier → right click

### 4.3 Coordinate mapping
In your `MetalLayerView`, implement pointer/gesture handlers and convert:
- `CGPoint` in view space → framebuffer coordinates

Key: aspect ratio differences.
If you letterbox the framebuffer into the view, apply the same math you used to map UVs, but in 2D:

```swift
func mapPointToFramebuffer(_ p: CGPoint, fbW: Int, fbH: Int, viewSize: CGSize) -> (x: Int, y: Int)? {
    let vw = viewSize.width, vh = viewSize.height
    let scale = min(vw / CGFloat(fbW), vh / CGFloat(fbH)) // contain
    let renderW = CGFloat(fbW) * scale
    let renderH = CGFloat(fbH) * scale
    let ox = (vw - renderW) * 0.5
    let oy = (vh - renderH) * 0.5

    let localX = p.x - ox
    let localY = p.y - oy
    guard localX >= 0, localY >= 0, localX < renderW, localY < renderH else { return nil }

    let x = Int(localX / scale)
    let y = Int(localY / scale)
    return (x, y)
}
```

This gives the equivalent of your old “hit→UV→XY” but without raycasts.

---

## 5. Nearest-Neighbor + Integer Scaling
With Metal you can enforce nearest sampling perfectly (shader sampler).
To keep UI crisp:
- Provide integer zoom options (1×,2×,3×)
- Or keep “contain” scaling but prefer snapping scale to nearest integer when possible

Optional: snap scale
```swift
let raw = min(vw/CGFloat(fbW), vh/CGFloat(fbH))
let snapped = max(1, floor(raw)) // integer down
```

---

## 6. Performance Notes
- `replaceRegion` each frame is usually fine at OpenRCT2 resolutions
- If you observe stalls:
  - allocate 2–3 textures and rotate (double/triple buffer)
  - upload from `MTLBuffer` + blit for better pipelining
- If OpenRCT2 exposes dirty rectangles, update only those regions

---

## 7. “Stop Starting Over” Migration Checklist
You should not redo:
- the bridge
- input semantics
- OpenRCT2 render pipeline

You only need:
- replace RK panel with MetalLayerView
- reuse your tick loop
- reuse your input-to-mouse mapping, swapping raycast coordinates for view coords

---

## 8. Acceptance Criteria
- Game renders in the window with correct colors
- Nearest-neighbor is visibly crisp
- Click/drag/scroll works as before
- No recurring per-frame allocations (no texture recreate every frame)
- Stable frame pacing under camera movement / scrolling

---

# Appendix A — If You Still Want an RK “Panel” Mode Later
Once Metal-backed window is stable, you can optionally reintroduce a “panel in space” mode by:
- keeping the Metal renderer and presenting into a texture
- mapping that texture into RealityKit as a material

That becomes a *feature*, not the foundation.
