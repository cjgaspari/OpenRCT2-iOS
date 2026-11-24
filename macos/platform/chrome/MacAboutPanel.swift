/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Native Mac About panel — 1:1 with classic About roles (title, description,
 * version, copy). Not Catalyst.
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacAboutPanel {
    static var versionString: String = "OpenRCT2"

    @MainActor
    static func show() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "About OpenRCT2"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.center()

        let root = AboutPanelView(version: versionString) {
            panel.close()
        }
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutPanelView: View {
    let version: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("OpenRCT2")
                .font(.title.weight(.semibold))
            Text("An open-source re-implementation of RollerCoaster Tycoon 2.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Text(version)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            HStack(spacing: 12) {
                Button("Copy Version") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(version, forType: .string)
                }
                .buttonStyle(.glass)
                Button("Close", action: onClose)
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
