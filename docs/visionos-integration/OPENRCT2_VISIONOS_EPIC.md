# OpenRCT2 visionOS MVP Epic (Metal Window)

> **Status**: Metal migration in progress  
> **Target**: visionOS 2.0+ (Apple Vision Pro)  
> **Approach**: SwiftUI window → UIViewRepresentable → CAMetalLayer + fullscreen triangle (nearest)  
> **Estimated Effort**: ~90-100 hours

---

## Executive Summary

We are replacing the RealityKit DrawableQueue path with a **Metal-backed window renderer**. The Swift/C++ bridge and game loop remain; only the display surface and sampling strategy change. The framebuffer from `X8DrawingEngine` is uploaded into an `MTLTexture` (BGRA8) via `replaceRegion`, then drawn through a minimal render pipeline to a `CAMetalLayer` drawable. Input now maps directly from UIView coordinates instead of RealityKit raycasts.

### Why switch to Metal window

1. **Deterministic frame pacing**: CAMetalLayer drawables + our own loop avoid RK scheduling quirks.
2. **Pixel-perfect output**: Nearest sampler eliminates unexpected filtering.
3. **Fewer moving parts**: No RealityView entities or DrawableQueue indirection; simpler threading story.
4. **Easier coordinate mapping**: UIKit pointer/gesture → framebuffer pixels (letterbox math) without 3D conversion.

### Keep vs Replace

- **Keep**: C ABI (`openrct2_*`), X8DrawingEngine framebuffer contract, palette format, input semantics (tap/drag/scroll/right-click), build scripts and toolchains.
- **Replace**: RealityKit plane + DrawableQueue + compute shader → CAMetalLayer with vertex/fragment pipeline and nearest sampler.

---

## Technical Architecture

### High-Level Data Flow

```
SwiftUI WindowGroup
    ↓
GameView (UIViewRepresentable)
    ↓
MetalLayerView (UIView + CAMetalLayer)
    ├─ drives CADisplayLink → rct2_update(dt)
    ├─ pulls frame via openrct2_get_frame_buffer()
    ├─ MTLTexture.replaceRegion(bytesPerRow = strideBytes)
    └─ fullscreen triangle draw (nearest sampler)

X8DrawingEngine (C++) → BGRA8 buffer + stride
```

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interop | Keep existing C ABI and Swift 5.9+ interop | No churn to game glue; focus on renderer swap |
| Display | CAMetalLayer + MTLCommandQueue | Direct control, no DrawableQueue dependency |
| Sampling | Nearest in fragment stage | Crisp UI pixels at any scale |
| Pixel format | Prefer BGRA8 from C++ (agreed); fragment swizzle fallback only if required | Matches Metal default; avoids per-frame swizzle |
| Stride contract | `bytesPerRow = width + pitch` from C ABI (agreed) | Prevents artifacts; single source of truth from C++ |
| Upload | `replaceRegion` using stride bytes | Minimal allocations; simple CPU copy |
| Draw loop | CADisplayLink inside Metal view drives `rct2_update`/`openrct2_tick` (agreed) | Predictable pacing; upload/draw on main; suspend when backgrounded |

### Minimal Shader Set

- Vertex: fullscreen triangle (no vertex buffers).
- Fragment: sample bound texture with `sampler(filter::nearest, address::clamp_to_edge)` and return `float4`; optional BGRA→RGBA swizzle only if engine cannot emit BGRA.

---

## Components to Build/Refactor

1. **MetalLayerView (new)**
   - Subclass `UIView`; `override class var layerClass -> CAMetalLayer`.
   - Owns `MTLDevice`, `MTLCommandQueue`, `MTLRenderPipelineState`, optional `MTLSamplerState` (nearest), optional depth disabled.
   - Holds reusable `MTLTexture` for the framebuffer; recreates only on size change.
   - Drives `CADisplayLink` to call `tick()` → `rct2_update(dt)` → upload → draw.

2. **GameView.swift (replace RealityView)**
   - `UIViewRepresentable` returning `MetalLayerView`.
   - Handles SwiftUI size changes; notifies engine on new framebuffer size; updates MetalLayerView drawable size.
   - Hosts gesture/pointer handlers; converts `CGPoint` → framebuffer coords using letterbox math.

3. **OpenRCT2Renderer.swift (retarget)**
   - Remove `TextureResource.DrawableQueue` and compute shader dependencies.
   - Provide APIs: `ensureTexture(width:height:)`, `upload(frame:ptr:strideBytes:)`, `draw(to:)`.
   - Manage reusable command buffer flow: begin → set pipeline → bind texture → draw triangle → present.

4. **GameEngine.swift (light touch)**
   - Keep C ABI calls; stop requesting DrawableQueue; expose `frameWidth/height/stride` helpers.
   - Optionally let MetalLayerView call `rct2_update` directly instead of a secondary loop.

5. **Shaders.metal (new)**
   - `vertex_main` fullscreen triangle; `fragment_main` samples texture0 with nearest sampler.
   - Optional BGRA→RGBA swizzle only if C++ cannot emit BGRA.

6. **Input mapping**
   - UIKit gestures (tap/drag/scroll/long-press) on MetalLayerView.
   - `mapPointToFramebuffer` helper snaps to contained region when letterboxed.

---

## Swift/C++ Interop Expectations

- Use existing symbols: `openrct2_get_frame_buffer`, `openrct2_get_palette`, `openrct2_get_pitch`, `openrct2_get_frame_width/height`, `openrct2_tick`, `openrct2_set_screen_size`.
- Framebuffer contract: BGRA8 pixels, `strideBytes = width + pitch` (from `RenderTarget.pitch`).
- Palette: still exposed for potential future compute path; not required if C++ outputs BGRA.

---

## Rendering Pipeline (Metal Window)

1. **Frame prep**
   - `CADisplayLink` inside Metal view calls `rct2_update(dt)`/`openrct2_tick()`.
   - Fetch width/height/stride via C ABI; stride = width + pitch.

2. **Texture management**
   - `ensureTexture` recreates `MTLTexture` when dimensions change (usage: `.shaderRead`).
   - `CAMetalLayer.drawableSize` set to view scale-adjusted size.

3. **Upload**
   - `replaceRegion(region: full frame, mip 0, withBytes: framebufferPtr, bytesPerRow: strideBytes)`.
   - Optionally double-buffer textures if profiling shows stalls.

4. **Draw**
   - Create command buffer → render pass targeting `nextDrawable.texture`.
   - Set pipeline + sampler + fragment texture (swizzle only if needed).
   - Draw 3 vertices (fullscreen triangle).
   - Present drawable; handle nil drawable by skipping when backgrounded.

5. **Timing**
   - Single display-link loop on main; pause when inactive.
   - If a separate game thread remains, limit it to logic only; render/upload stays on main.

---

## Input Mapping (Window Coordinates)

- Pointer/gesture handlers live on MetalLayerView.
- Convert `CGPoint` → framebuffer `(x,y)` with contain-scale and offsets:
  - `scale = min(viewW/fbW, viewH/fbH)`
  - `renderW = fbW * scale`, `renderH = fbH * scale`
  - `ox = (viewW - renderW) / 2`, `oy = (viewH - renderH) / 2`
  - Reject events outside `[ox, ox+renderW) × [oy, oy+renderH)`
- Map gestures:
  - Tap → left click down/up
  - Drag → move + left down
  - Scroll → mouse wheel
  - Long press (optional) → right click

---

## Build and Packaging Notes

- Reuse current CMake toolchains and vcpkg triplets; no change required for the renderer swap.
- Swift build settings: C++ interop remains (`-cxx-interoperability-mode=default`).
- Add Metal shader to build phases; ensure `Shaders.metal` is in a Metal library target or app target.

---

## Success Criteria (Metal MVP)

- Live gameplay renders in window with correct colors and crisp pixels.
- Texture not recreated per frame; resize-only recreation verified via logging.
- Input parity with prior RealityKit path (click, drag, scroll, right-click).
- No recurring frame pacing hitches over 15+ minutes of play.

---

## Ticket Summary (Updated for Metal)

| Milestone | Tickets | Description |
|-----------|---------|-------------|
| M1 | VOS-001→005 | Project + interop foundations (unchanged) |
| M2 | VOS-010→014 | UiContext + C ABI frame/palette access (unchanged) |
| M3 | VOS-020→024 | CAMetalLayer renderer, shaders, upload path |
| M4 | VOS-030→033 | SwiftUI host + resize + MetalLayerView integration |
| M5 | VOS-040→044 | Input mapping in view coords (UIKit gestures) |
| M6 | VOS-050→053 | AVFoundation audio (optional/unchanged) |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Stride mismatch causing artifacts | Medium | High | Always use `bytesPerRow = strideBytes` from C ABI; add assertions in Swift |
| Texture recreate on every frame | Low | High | Cache `MTLTexture`; recreate only on size change |
| Color channel swap if engine stays RGBA | Medium | Medium | Add fragment swizzle fallback; prefer BGRA in C++ |
| UI latency from CADisplayLink on main | Low | Medium | Keep game tick lightweight; offload heavy work to background if needed |
| RealityKit dependencies lingering in code | Medium | Low | Remove DrawableQueue/RealityView imports during refactor |

---

## Stretch Goals (post-stability)

- Optional double-buffer upload (MTLBuffer + blit) if replaceRegion stalls.
- Optional RealityKit panel mode backed by Metal texture after window path is solid.
- Optional compute path for palette conversion if C++ cannot emit BGRA.

---

## References

- SPEC: [SPEC_Migrate_RealityKit_to_Metal_Window.md](SPEC_Migrate_RealityKit_to_Metal_Window.md)
- Notes: [metal-cpp-notes.md](metal-cpp-notes.md)
- Swift C++ Interop: https://www.swift.org/documentation/cxx-interop/
- Metal best practices: https://developer.apple.com/metal/
