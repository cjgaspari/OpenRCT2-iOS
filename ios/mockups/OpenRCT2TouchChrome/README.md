# OpenRCT2 Touch chrome mockups

A standalone SwiftUI app for iterating native iPhone portrait chrome **without rebuilding the game**.

Open `OpenRCT2TouchChrome.xcodeproj` in Xcode 26+, choose an iPhone Simulator, and Run.

The park canvas is a green-to-blue gradient, not RCT2 art. Live cash/guest figures tick so you can judge tabular-digit width.

## Mixer

The center **Chrome mixer** pairs any top bar with any bottom bar (3 × 3). Left-handed controls swap the bottom clusters.

Chrome is based on the live overlay: tabular status, pause menu with zoom, equal-size Trees / Build / Paths, and a tools+rotate `glassEffectUnion`.

## Top (info + pause)

1. **Union** — Status and pause share one leading Liquid Glass capsule. Two menus, one blob.
2. **HUD** — One control: pause, speed, and cash. Camera, Park, and More live in that menu.
3. **Island** — One centered island: pause plus cash and guests. Two menus, one shape.

## Bottom (build + tools)

1. **Split** — Live layout: equal Trees / Build / Paths, tools+rotate union on the thumb.
2. **Bar** — One bottom toolbar. Build trio and tools/rotate sit in the same glass bar.
3. **Labeled** — Captioned Trees / Build / Paths; vertical tools+rotate on the thumb.

The grid button still opens the Park Tools half-to-full sheet (list scrolls at medium; drag the sheet up for large).

Liquid Glass is applied only to the navigation layer (`.buttonStyle(.glass)`, `GlassEffectContainer`, `glassEffectUnion`). The sheet is not wrapped in extra `glassEffect`.
