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
    /// HIG Materials: dark dimming ~35% under clear glass over rich media.
    /// Tunable after eye-test (~0.20…0.45).
    static var dimmingOpacity: CGFloat = 0.35

    static let cornerRadius: CGFloat = 18
    static let glassStyle: NSGlassEffectView.Style = .clear

    /// Localized text plate — prefer under list/detail columns, not a full wash.
    static func textPlate(cornerRadius: CGFloat = 10) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(dimmingOpacity))
    }

    static var primaryLabel: Color { Color(nsColor: .labelColor) }
    static var secondaryLabel: Color { Color(nsColor: .secondaryLabelColor) }
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

        let sizedRoot = AnyView(
            root
                .frame(minWidth: size.width, minHeight: size.height)
                .preferredColorScheme(.dark)
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
