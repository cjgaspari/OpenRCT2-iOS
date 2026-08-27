# OpenRCT2 Touch chrome mockups

A standalone SwiftUI app for iterating native iPhone portrait chrome **without rebuilding the game**.

Open `OpenRCT2TouchChrome.xcodeproj` in Xcode 26+, choose an iPhone Simulator, and Run. Use the top-left glass menu to switch layouts. Tapping a tool shows a stand-in for the existing in-engine window.

The park canvas is a green-to-blue gradient, not RCT2 art.

## Layouts

1. **Cluster** — Floating bottom glass cluster (Trees / + / Paths / More), camera row (pause, 1x/2x speed, zoom in/out, rotate), and Park Tools sheet. Closest to the live overlay.
2. **Rail** — Maps-style trailing vertical tool rail.
3. **FAB** — One prominent build button that morphs into land, water, trees, paths, and rides.
4. **Sheet** — Find My pattern: inset sheet with grabber, detents, integrated tab bar (Build / Park / View / More), and corner glass controls. The park stays interactive at the compact detent.

Liquid Glass is applied only to the navigation layer (`.buttonStyle(.glass)` / `.glassProminent`, `GlassEffectContainer`, system `TabView` / sheet). The sheet is **not** wrapped in extra `glassEffect`.

## Mapping

Chrome actions correspond to play-mode top/bottom toolbar intents (`constructRide`, scenery, footpath, land, water, park, staff, guests, finances, research, view options, file/options/cheats). The game still owns those windows.
