# Metal Migration Analysis (RealityKit → CAMetalLayer)

Purpose: outline concrete changes needed to move the current visionOS branch from RealityKit/DrawableQueue to a Metal-backed window renderer while keeping the C++ bridge and game loop stable.

## Current Implementation Snapshot

- Renderer: RealityKit `TextureResource.DrawableQueue` + compute shader for palette (`convertIndexedToRGBA`) inside [Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift](Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift).
- View: [Sources/OpenRCT2App/GameView.swift](Sources/OpenRCT2App/GameView.swift) uses `RealityView` with a plane entity, binds DrawableQueue textures, resizes via plane mesh regeneration.
- Engine loop: [Sources/OpenRCT2App/GameEngine.swift](Sources/OpenRCT2App/GameEngine.swift) drives `openrct2_tick`, copies palette, uploads frame to DrawableQueue, and exposes `getDrawableQueue()` for RealityKit.
- Renderer stub: [Sources/OpenRCT2App/GameRenderer.swift](Sources/OpenRCT2App/GameRenderer.swift) is unused placeholder.
- C ABI: `openrct2_get_frame_buffer`, `openrct2_get_palette`, `openrct2_get_pitch`, `openrct2_set_screen_size`, etc., already exposed and used.

## Target Architecture (Metal Window)

SwiftUI WindowGroup → `UIViewRepresentable` → `MetalLayerView` (UIView + CAMetalLayer) → `MTLCommandQueue` + render pipeline (fullscreen triangle, nearest sampler) → `replaceRegion` upload of BGRA framebuffer → present drawable.

## Migration Plan (with agreed decisions)

1) Replace renderer to use CAMetalLayer
- Rework [Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift](Sources/OpenRCT2App/Rendering/OpenRCT2Renderer.swift): drop DrawableQueue/RealityKit/compute paths; manage `MTLDevice`, `MTLCommandQueue`, `MTLTexture` reuse, and a simple render pipeline + sampler.
- Add `ensureTexture(width:height:)`, `upload(framePtr:strideBytes:)`, `draw(to drawable:)` helpers; stride uses `bytesPerRow = width + pitch` from the C ABI (agreed).
- Prefer BGRA frames from C++; keep palette API only for optional fragment swizzle fallback if RGBA persists.

2) Introduce MetalLayerView (new)
- UIView subclass with `override class var layerClass -> CAMetalLayer`.
- Owns renderer instance; sets `metalLayer.pixelFormat = .bgra8Unorm`, `framebufferOnly = true`.
- Drives `CADisplayLink` → `tick()` that calls `rct2_update`/`openrct2_tick`, fetches frame pointer/stride/size, calls renderer upload + draw (single agreed driver on main).
- Manages drawableSize and recreates texture only on size change.

3) Swap GameView to UIViewRepresentable
- Rewrite [Sources/OpenRCT2App/GameView.swift](Sources/OpenRCT2App/GameView.swift) to host `MetalLayerView` instead of `RealityView`.
- Remove RealityKit imports/usages; manage size via GeometryReader and call `openrct2_set_screen_size` when contained size changes.
- Provide environment hooks to start/stop the display link when the view appears/disappears.

4) Adjust GameEngine loop
- Adopt the MetalLayerView display link as the single tick driver; avoid double-ticking with the existing engine queue.
- Remove `getDrawableQueue()` exposure; replace with helpers for width/height/stride/pixels.
- Ensure width/height used for texture creation come from C++ getters to avoid desync.

5) Add Metal shaders
- Create `Shaders.metal` in Rendering/Shaders with `vertex_main` (fullscreen triangle) and `fragment_main` (nearest sampler); include optional BGRA→RGBA swizzle only if C++ cannot emit BGRA.
- Build as part of the app target; no compute pipeline needed.

6) Input mapping on MetalLayerView
- Attach UIKit gestures (tap, long-press, pan, scroll). Map `CGPoint` → framebuffer coords using contain-scale + letterboxing math; drop RealityKit hit-tests.
- Feed mapped coordinates into existing InputBridge/C ABI cursor setters; clear button states on gesture cancel/end.

7) Cleanup and dependency removal
- Delete/ignore RealityKit-specific code paths and imports in renderer/view.
- Remove `TextureResource.DrawableQueue` usage and placeholder `GameRenderer.swift` if superseded.

8) Validation & instrumentation
- Log when textures are recreated (should be resize-only).
- Add lightweight FPS/frame pacing counters during bring-up.
- Test color correctness (BGRA) and stride correctness after migration; pause/present gracefully when `nextDrawable` is nil (backgrounded).

## Risks / Watchouts

- Stride mismatch: must use `bytesPerRow = width + pitch` from `openrct2_get_pitch()`; otherwise banding/tearing.
- BGRA vs RGBA: if C++ still outputs RGBA, add fragment swizzle or request BGRA from C++ drawing path (preferred BGRA agreed).
- Tick contention: ensure only the MetalLayerView display link drives tick/upload/draw; avoid double ticks if old engine thread lingers.
- Drawable availability: CAMetalLayer `nextDrawable()` can return nil when backgrounded—pause display link appropriately.
- Input offsets: letterboxing math must match render scale to avoid misaligned clicks; write unit tests for mapping helper.

## Definition of Done for Migration

- RealityKit/DrawableQueue removed from shipping code path.
- MetalLayerView presents live game frames with nearest sampling and correct colors.
- No per-frame texture recreation; resize-only.
- Input parity: click/drag/scroll/right-click behave as before.
- 15+ minutes stable play without frame pacing hitches.
