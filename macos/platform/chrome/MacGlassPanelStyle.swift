/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Locked mid-legibility style for Mac Liquid Glass panels (CJ Option A + HIG
 * dimming). Clear NSGlassEffectView with tunable dark dimming under text —
 * not inactive-window frost, not flat black/white sheets.
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacGlassPanelStyle {
    /// Clear glass over bright park media (water/sky): eye-test bump to ~0.50
    /// (CJ: 0.45–0.55). Still localized under list/detail — not full opaque wash.
    static var dimmingOpacity: CGFloat = 0.50

    static let cornerRadius: CGFloat = 18
    static let glassStyle: NSGlassEffectView.Style = .clear

    /// Localized frosted + dark plate under text columns so park still shows
    /// through clear glass around the plates.
    static func textPlate(cornerRadius: CGFloat = 10) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(dimmingOpacity))
            }
    }

    /// Explicit high-contrast light labels — system labelColor can stay dark
    /// over bright park water even with preferredColorScheme(.dark).
    static var primaryLabel: Color { Color.white }
    static var secondaryLabel: Color { Color.white.opacity(0.78) }
}

/// Clear NSPanel + NSGlassEffectView.contentView — shared host for title browsers
/// and (once style locked) earlier dense panels.
enum MacGlassPanelHost {
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
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = minSize
        // Force dark aqua so controls/vibrant bits stay light on clear glass.
        panel.appearance = NSAppearance(named: .darkAqua)

        let sizedRoot = AnyView(
            root
                .frame(minWidth: size.width, minHeight: size.height)
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
        )
        let host = NSHostingView(rootView: sizedRoot)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let glass = NSGlassEffectView()
        glass.style = MacGlassPanelStyle.glassStyle
        glass.cornerRadius = MacGlassPanelStyle.cornerRadius
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
        return panel
    }
}
