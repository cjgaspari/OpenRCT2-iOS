/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Classic title-screen layout in Liquid Glass:
 *   Logo TL · Options TR · New/Load/Network/Tools bottom-center ·
 *   Exit BR · version BL
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacChromeTitleAction: Int32 {
    case newGame = 10010
    case loadGame = 10011
    case options = 10012
    case quit = 10013
    case network = 10014
    case about = 10016
    /// Tools dropdown — `extra` is classic TitleMenu tools index.
    case tools = 10015
}

/// Full-window classic title chrome (not a single capsule).
struct MacTitleChromeLayout: View {
    @ObservedObject var model: MacParkChromeModel
    @State private var toolsAnchor = ToolbarButtonAnchor()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topRow
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
                bottomRow
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }

            VStack {
                Spacer(minLength: 0)
                centerActions
                    .padding(.bottom, 56)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("openrct2.mac.titleChrome")
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            logoButton
            Spacer(minLength: 12)
            MacGlassChipButton(title: "Options", systemImage: "gearshape") {
                model.queueTitle(.options)
            }
            .padding(.top, 4)
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                MacGlassSecondaryText(text: model.versionString, size: 11)
                MacGlassSecondaryText(text: "macOS", size: 10)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Version \(model.versionString)")

            Spacer(minLength: 12)

            MacGlassChipButton(title: "Exit", systemImage: "xmark") {
                model.queueTitle(.quit)
            }
        }
    }

    private var centerActions: some View {
        HStack(spacing: 12) {
            MacGlassIconTile(
                title: "New Game",
                systemImage: "plus.square.fill",
                tint: Color.green.opacity(0.5)
            ) {
                model.queueTitle(.newGame)
            }
            MacGlassIconTile(
                title: "Load Game",
                systemImage: "folder.fill",
                tint: Color.green.opacity(0.5)
            ) {
                model.queueTitle(.loadGame)
            }
            MacGlassIconTile(
                title: "Network",
                systemImage: "person.3.fill",
                tint: Color.blue.opacity(0.5)
            ) {
                model.queueTitle(.network)
            }
            toolsTile
        }
    }

    private var toolsTile: some View {
        MacGlassIconTile(
            title: "Tools",
            systemImage: "wrench.and.screwdriver.fill",
            tint: Color.red.opacity(0.5)
        ) {
            popToolsMenu()
        }
        .background(ToolbarButtonAnchorReader(anchor: toolsAnchor))
    }

    /// Classic OpenRCT2 logo TL: blue diamond + yellow Open / red RCT2 badge.
    private var logoButton: some View {
        Button {
            MacAboutPanel.show()
        } label: {
            HStack(spacing: 8) {
                if let logo = MacToolbarIconStore.titleLogoImage() {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(height: 72)
                }
                if let wordmark = MacToolbarIconStore.titleWordmarkImage() {
                    Image(nsImage: wordmark)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(height: 56)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About OpenRCT2")
    }

    private func popToolsMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let titles = [
            "Scenario Editor",
            "Convert Saved Game to Scenario",
            "Roller Coaster Designer",
            "Track Designs Manager",
            "Open User Content Folder",
        ]
        for (i, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(TitleToolsTarget.selected(_:)), keyEquivalent: "")
            item.tag = i
            item.target = TitleToolsTarget.shared
            item.isEnabled = true
            menu.addItem(item)
        }
        TitleToolsTarget.shared.handler = { index in
            model.queueTitle(.tools, extra: Int32(index))
        }
        if let view = toolsAnchor.view {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
        } else if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

@MainActor
final class TitleToolsTarget: NSObject {
    static let shared = TitleToolsTarget()
    var handler: ((Int) -> Void)?

    @objc func selected(_ sender: NSMenuItem) {
        handler?(sender.tag)
    }
}

extension MacToolbarIconStore {
    static func titleLogoImage() -> NSImage? {
        classicG2Image(named: "logo.png")
    }

    static func titleWordmarkImage() -> NSImage? {
        classicG2Image(named: "logo_text.png")
    }

    /// Classic g2 title art (`logo.png` / `logo_text.png`) — never SF Symbol ship.
    private static func classicG2Image(named file: String) -> NSImage? {
        for url in classicG2Candidates(file) {
            if FileManager.default.fileExists(atPath: url.path),
               let image = NSImage(contentsOf: url)
            {
                return image
            }
        }
        return nil
    }

    private static func classicG2Candidates(_ file: String) -> [URL] {
        var urls: [URL] = []
        if let icons = iconDirectory {
            urls.append(icons.deletingLastPathComponent().appendingPathComponent(file))
        }
        if let root = ProcessInfo.processInfo.environment["OPENRCT2_ROOT"], !root.isEmpty {
            urls.append(
                URL(fileURLWithPath: root)
                    .appendingPathComponent("resources/g2", isDirectory: true)
                    .appendingPathComponent(file)
            )
        }
        // Walk up from the running binary (install/bin → repo root).
        let argv0 = CommandLine.arguments.first.map { URL(fileURLWithPath: $0) }
        var dir = (Bundle.main.executableURL ?? argv0)?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let current = dir else { break }
            urls.append(
                current.appendingPathComponent("resources/g2", isDirectory: true)
                    .appendingPathComponent(file)
            )
            dir = current.deletingLastPathComponent()
        }
        return urls
    }
}
