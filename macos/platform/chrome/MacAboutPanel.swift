/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Native Mac About panel — 1:1 with classic About roles (title, description,
 * version, copy). Mid-legibility clear Liquid Glass.
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacAboutPanel {
    static var versionString: String = "OpenRCT2"
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() {
        guard MacUILabPrefs.shared.isNativeEnabled(.about) else { return }
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        panel = MacGlassPanelHost.present(
            title: "About OpenRCT2",
            size: NSSize(width: 420, height: 280),
            minSize: NSSize(width: 360, height: 220),
            resizable: false,
            root: AboutPanelView(version: versionString) {
                panel?.close()
                panel = nil
            }
        )
    }
}

private struct AboutPanelView: View {
    let version: String
    let onClose: () -> Void

    var body: some View {
        MacGlassContentSurface(padding: 24, cornerRadius: 14) {
            VStack(spacing: 16) {
                MacGlassPrimaryText(text: "OpenRCT2", size: 22, weight: .semibold)
                Text("An open-source re-implementation of RollerCoaster Tycoon 2.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MacGlassPanelStyle.secondaryLabel)
                    .padding(.horizontal)
                Text(version)
                    .font(.caption.monospaced())
                    .foregroundStyle(MacGlassPanelStyle.primaryLabel)
                    .textSelection(.enabled)
                // Close = traffic lights only.
                Button("Copy Version") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(version, forType: .string)
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
