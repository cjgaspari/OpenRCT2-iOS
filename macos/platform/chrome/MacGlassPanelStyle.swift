/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Live-tunable mid-legibility Liquid Glass knobs (CJ Glass Style Lab).
 * Clear/regular glass + localized frost/dimming; park show-through preserved.
 *****************************************************************************/

import AppKit
import SwiftUI

@MainActor
@Observable
final class MacGlassStyleKnobs {
    static let shared = MacGlassStyleKnobs()

    // Glass chrome — locked CJ Lab defaults (2026-11-24)
    var useClearGlass: Bool = false // Regular glass
    var cornerRadius: Double = 18
    var tintEnabled: Bool = false
    var tintHue: Double = 0.55
    var tintSaturation: Double = 0.20
    var tintBrightness: Double = 0.35
    var tintOpacity: Double = 0.30

    // Text plates
    var dimmingOpacity: Double = 0.15
    var localizedFrost: Bool = true
    var useThinMaterial: Bool = true
    var materialOpacity: Double = 0.00
    var plateCornerRadius: Double = 20

    // Labels
    var primaryWhite: Double = 1.0
    var secondaryWhite: Double = 0.78
    var forceDarkAqua: Bool = true

    var glassStyle: NSGlassEffectView.Style { useClearGlass ? .clear : .regular }

    var primaryLabel: Color { Color.white.opacity(primaryWhite) }
    var secondaryLabel: Color { Color.white.opacity(secondaryWhite) }

    var nsTintColor: NSColor? {
        guard tintEnabled else { return nil }
        return NSColor(
            hue: tintHue,
            saturation: tintSaturation,
            brightness: tintBrightness,
            alpha: tintOpacity
        )
    }

    func resetDefaults() {
        useClearGlass = false
        cornerRadius = 18
        tintEnabled = false
        tintHue = 0.55
        tintSaturation = 0.20
        tintBrightness = 0.35
        tintOpacity = 0.30
        dimmingOpacity = 0.15
        localizedFrost = true
        useThinMaterial = true
        materialOpacity = 0.00
        plateCornerRadius = 20
        primaryWhite = 1.0
        secondaryWhite = 0.78
        forceDarkAqua = true
        MacGlassPanelHost.applyLiveChrome()
    }

    /// Call after any knob edit so AppKit glass chrome updates immediately.
    func applyChrome() {
        MacGlassPanelHost.applyLiveChrome()
    }
}

/// Compatibility façade used by older call sites (MainActor UI only).
@MainActor
enum MacGlassPanelStyle {
    static var dimmingOpacity: CGFloat {
        get { MacGlassStyleKnobs.shared.dimmingOpacity }
        set { MacGlassStyleKnobs.shared.dimmingOpacity = newValue }
    }

    static var cornerRadius: CGFloat { MacGlassStyleKnobs.shared.cornerRadius }
    static var glassStyle: NSGlassEffectView.Style { MacGlassStyleKnobs.shared.glassStyle }
    static var primaryLabel: Color { MacGlassStyleKnobs.shared.primaryLabel }
    static var secondaryLabel: Color { MacGlassStyleKnobs.shared.secondaryLabel }

    @ViewBuilder
    static func textPlate(cornerRadius: CGFloat? = nil) -> some View {
        MacGlassTextPlate(cornerRadius: cornerRadius)
    }
}

struct MacGlassTextPlate: View {
    var cornerRadius: CGFloat?
    @Bindable private var knobs = MacGlassStyleKnobs.shared

    var body: some View {
        let radius = cornerRadius ?? knobs.plateCornerRadius
        ZStack {
            if knobs.useThinMaterial {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(knobs.materialOpacity)
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(knobs.dimmingOpacity))
        }
    }
}

/// Optional full-panel wash when localized frost is off.
struct MacGlassFullWash: View {
    @Bindable private var knobs = MacGlassStyleKnobs.shared

    var body: some View {
        if !knobs.localizedFrost {
            MacGlassTextPlate(cornerRadius: 0)
                .ignoresSafeArea()
        }
    }
}

/// Rounded selection fill, inset so corners stay concentric with list plates.
struct MacGlassSelectionBackground: View {
    var selected: Bool
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if selected {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.accentColor.opacity(0.28))
                    .padding(3)
            } else {
                Color.clear
            }
        }
    }
}

private final class MacGlassPanelEntry {
    weak var panel: NSPanel?
    weak var glass: NSGlassEffectView?
}

/// Clear/regular NSPanel + NSGlassEffectView.contentView — shared host.
enum MacGlassPanelHost {
    @MainActor private static var registry: [MacGlassPanelEntry] = []

    @MainActor
    static func present(
        title: String,
        size: NSSize,
        minSize: NSSize = NSSize(width: 320, height: 200),
        resizable: Bool = true,
        root: some View
    ) -> NSPanel {
        var style: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if resizable {
            style.insert(.resizable)
        }
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.titlebarAppearsTransparent = true
        // Show title in the transparent titlebar; Close = traffic lights only.
        panel.titleVisibility = .visible
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = minSize

        let knobs = MacGlassStyleKnobs.shared
        if knobs.forceDarkAqua {
            panel.appearance = NSAppearance(named: .darkAqua)
        }

        let sizedRoot = AnyView(
            root
                .frame(minWidth: size.width, minHeight: size.height)
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .background { MacGlassFullWash() }
        )
        let host = NSHostingView(rootView: sizedRoot)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let glass = NSGlassEffectView()
        glass.style = knobs.glassStyle
        glass.cornerRadius = knobs.cornerRadius
        glass.tintColor = knobs.nsTintColor
        glass.contentView = host
        glass.frame = NSRect(origin: .zero, size: size)
        glass.autoresizingMask = [.width, .height]

        panel.contentView = glass
        panel.center()
        if let screen = panel.screen ?? NSScreen.main {
            var frame = panel.frame
            let topLimit = screen.visibleFrame.maxY - 80
            if frame.maxY > topLimit {
                frame.origin.y -= (frame.maxY - topLimit)
                panel.setFrame(frame, display: true)
            }
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let entry = MacGlassPanelEntry()
        entry.panel = panel
        entry.glass = glass
        registry.append(entry)
        pruneRegistry()
        MacGlassStyleLab.installHotkeyIfNeeded()
        return panel
    }

    @MainActor
    static func applyLiveChrome() {
        pruneRegistry()
        let knobs = MacGlassStyleKnobs.shared
        for entry in registry {
            guard let glass = entry.glass else { continue }
            glass.style = knobs.glassStyle
            glass.cornerRadius = knobs.cornerRadius
            glass.tintColor = knobs.nsTintColor
            if let panel = entry.panel {
                panel.appearance = knobs.forceDarkAqua ? NSAppearance(named: .darkAqua) : nil
            }
        }
    }

    @MainActor
    private static func pruneRegistry() {
        registry.removeAll { $0.panel == nil || $0.glass == nil }
    }
}
