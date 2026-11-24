/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * First-class macOS menu bar — File / Edit / View / Window / Help.
 * Mirrors existing in-game NSMenu items (same WIDX + dropdown indices) so
 * toolbar pop-ups stay unchanged; menu bar is an additional surface.
 *****************************************************************************/

import AppKit

/// Extra codes outside WIDX_* for Edit / Help menu actions.
enum MacChromeMenuAction: Int32 {
    case closeTop = 10020
    case closeAll = 10021
    case keyboardShortcuts = 10022
}

@MainActor
enum MacMenuBar {
    private static var installed = false
    private static var actionHandler: ((Int32, Int32) -> Void)?

    static func install(actionHandler: @escaping (Int32, Int32) -> Void) {
        Self.actionHandler = actionHandler
        MenuBarTarget.shared.handler = { widx, extra in
            if widx == MacToolbarWIDX.fileMenu.rawValue, extra == 9 {
                MacAboutPanel.show()
                return
            }
            actionHandler(widx, extra)
        }

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        let mainMenu = NSMenu()

        // —— OpenRCT2 (app) ——
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        appMenu.addItem(command("About OpenRCT2", widx: .fileMenu, extra: 9))
        appMenu.addItem(.separator())
        let settings = command("Settings…", widx: .fileMenu, extra: 12)
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settings)
        appMenu.addItem(.separator())

        let hide = NSMenuItem(title: "Hide OpenRCT2", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        appMenu.addItem(hide)
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        appMenu.addItem(hideOthers)
        let showAll = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAll.target = NSApp
        appMenu.addItem(showAll)
        appMenu.addItem(.separator())
        let quit = command("Quit OpenRCT2", widx: .fileMenu, extra: 15)
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quit)

        // —— File ——
        mainMenu.addItem(submenu("File", items: fileItems()))

        // —— Edit ——
        mainMenu.addItem(submenu("Edit", items: editItems()))

        // —— View ——
        mainMenu.addItem(submenu("View", items: viewItems()))

        // —— Window ——
        let windowMenuItem = submenu("Window", items: windowItems())
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenuItem.submenu

        // —— Help ——
        let helpMenuItem = submenu("Help", items: helpItems())
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenuItem.submenu

        NSApp.mainMenu = mainMenu
        installed = true
    }

    static func ensureInstalled(actionHandler: @escaping (Int32, Int32) -> Void) {
        if installed {
            Self.actionHandler = actionHandler
            MenuBarTarget.shared.handler = { widx, extra in
                if widx == MacToolbarWIDX.fileMenu.rawValue, extra == 9 {
                    MacAboutPanel.show()
                    return
                }
                actionHandler(widx, extra)
            }
            return
        }
        install(actionHandler: actionHandler)
    }

    // MARK: - Menus

    private static func fileItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        items.append(command("New Game", widx: .fileMenu, extra: 0, key: "n"))
        items.append(command("Load Game…", widx: .fileMenu, extra: 1, key: "o"))
        items.append(.separator())
        items.append(command("Save Game", widx: .fileMenu, extra: 3, key: "s"))
        items.append(command("Save Game As…", widx: .fileMenu, extra: 4, key: "s", flags: [.command, .shift]))
        items.append(.separator())
        // Engine defaults: CTRL+S screenshot / CTRL+SHIFT+S giant → ⌃S / ⇧⌃S
        // (⌘S reserved for Save above — first-class macOS File menu).
        items.append(command("Screenshot", widx: .fileMenu, extra: 6, key: "s", flags: [.control]))
        items.append(command("Giant Screenshot", widx: .fileMenu, extra: 7, key: "s", flags: [.control, .shift]))
        items.append(.separator())
        items.append(contentsOf: toolbarIconsItems())
        items.append(.separator())
        items.append(command("Quit to Menu", widx: .fileMenu, extra: 14))
        return items
    }

    private static func editItems() -> [NSMenuItem] {
        [
            command("Close Window", code: MacChromeMenuAction.closeTop.rawValue, key: "w"),
            command("Close All Windows", code: MacChromeMenuAction.closeAll.rawValue, key: "w", flags: [.command, .shift]),
            .separator(),
            command("Keyboard Shortcuts…", code: MacChromeMenuAction.keyboardShortcuts.rawValue, key: "/", flags: [.command, .shift]),
        ]
    }

    private static func viewItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        items.append(command("Pause", widx: .pause, extra: 0))
        items.append(submenuItem("Game Speed", children: [
            command("Normal Speed", widx: .fastForward, extra: 0),
            command("Quick Speed", widx: .fastForward, extra: 1),
            command("Fast Speed", widx: .fastForward, extra: 2),
            command("Turbo Speed", widx: .fastForward, extra: 3),
            .separator(),
            command("Hyper Speed", widx: .fastForward, extra: 5),
        ]))
        items.append(command("Mute", widx: .mute, extra: 0))
        items.append(.separator())
        items.append(command("Zoom In", widx: .zoomIn, extra: 0, key: "=", flags: [.command]))
        items.append(command("Zoom Out", widx: .zoomOut, extra: 0, key: "-", flags: [.command]))
        items.append(command("Rotate Clockwise", widx: .rotateClockwise, extra: 0))
        items.append(command("Rotate Anti-Clockwise", widx: .rotateAntiClockwise, extra: 0))
        items.append(.separator())
        // ViewMenuDdidx — same indices as toolbar View pop-up
        items.append(command("Underground View", widx: .viewMenu, extra: 0, key: "1", flags: [.command]))
        items.append(command("Transparent Water", widx: .viewMenu, extra: 1, key: "2", flags: [.command]))
        items.append(command("Remove Base Land", widx: .viewMenu, extra: 2))
        items.append(command("Remove Vertical Faces", widx: .viewMenu, extra: 3))
        items.append(.separator())
        items.append(command("See-through Rides", widx: .viewMenu, extra: 5, key: "3", flags: [.command]))
        items.append(command("See-through Vehicles", widx: .viewMenu, extra: 6))
        items.append(command("See-through Vegetation", widx: .viewMenu, extra: 7))
        items.append(command("See-through Scenery", widx: .viewMenu, extra: 8, key: "4", flags: [.command]))
        items.append(command("See-through Paths", widx: .viewMenu, extra: 9))
        items.append(command("See-through Supports", widx: .viewMenu, extra: 10, key: "5", flags: [.command]))
        items.append(command("See-through Guests", widx: .viewMenu, extra: 11, key: "6", flags: [.command]))
        items.append(command("See-through Staff", widx: .viewMenu, extra: 12))
        items.append(.separator())
        items.append(command("Height Marks on Land", widx: .viewMenu, extra: 14, key: "8", flags: [.command]))
        items.append(command("Height Marks on Tracks", widx: .viewMenu, extra: 15, key: "9", flags: [.command]))
        items.append(command("Height Marks on Paths", widx: .viewMenu, extra: 16, key: "0", flags: [.command]))
        items.append(.separator())
        items.append(command("View Clipping…", widx: .viewMenu, extra: 18))
        items.append(command("Highlight Path Issues", widx: .viewMenu, extra: 19))
        items.append(.separator())
        items.append(command("Transparency Options…", widx: .viewMenu, extra: 21, key: "t"))
        return items
    }

    private static func windowItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        // ⌘M reserved for standard Minimize below (macOS).
        items.append(command("Show Map", widx: .map, extra: 0))
        items.append(command("Extra Viewport", widx: .map, extra: 1))
        items.append(.separator())
        items.append(command("Finances", widx: .finances, extra: 0, key: "f"))
        items.append(command("Research", widx: .research, extra: 0, key: "d"))
        items.append(command("Rides", widx: .rides, extra: 0, key: "r"))
        items.append(command("Park Information", widx: .park, extra: 0, key: "p"))
        items.append(command("Staff", widx: .staff, extra: 0, key: "s", flags: [.command, .option]))
        items.append(command("Guests", widx: .guests, extra: 0, key: "g"))
        items.append(command("Recent Messages", widx: .news, extra: 0, key: "m", flags: [.command, .option]))
        items.append(.separator())
        items.append(submenuItem("Tools", children: [
            command("Clear Scenery", widx: .clearScenery, extra: 0),
            command("Adjust Land", widx: .land, extra: 0),
            command("Adjust Water", widx: .water, extra: 0),
            command("Place Scenery", widx: .scenery, extra: 0),
            command("Build Footpath", widx: .path, extra: 0),
            command("Build Ride", widx: .constructRide, extra: 0),
        ]))
        items.append(submenuItem("Cheats", children: [
            command("Cheats…", widx: .cheats, extra: 0, key: "c", flags: [.command, .option]),
            command("Tile Inspector…", widx: .cheats, extra: 1),
            command("Object Selection…", widx: .cheats, extra: 2),
            command("Inventions List…", widx: .cheats, extra: 3),
            command("Scenario Options…", widx: .cheats, extra: 4),
            .separator(),
            command("Enable Sandbox Mode", widx: .cheats, extra: 6),
            command("Disable Clearance Checks", widx: .cheats, extra: 7),
            command("Disable Support Limits", widx: .cheats, extra: 8),
        ]))
        items.append(submenuItem("Debug", children: [
            command("Console", widx: .debug, extra: 0),
            command("Debug Paint", widx: .debug, extra: 1),
        ]))
        items.append(submenuItem("Network", children: [
            command("Multiplayer…", widx: .network, extra: 0),
            command("Reconnect", widx: .network, extra: 1),
            command("Chat", widx: .chat, extra: 0),
        ]))
        items.append(.separator())
        let minimize = NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        // First responder / key window — standard macOS ⌘M.
        items.append(minimize)
        return items
    }

    private static func helpItems() -> [NSMenuItem] {
        [
            command("Keyboard Shortcuts…", code: MacChromeMenuAction.keyboardShortcuts.rawValue, key: "/", flags: [.command, .shift]),
            .separator(),
            command("File Bug on GitHub", widx: .fileMenu, extra: 10),
        ]
    }

    private static func toolbarIconsItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        if #available(macOS 14.0, *) {
            items.append(.sectionHeader(title: "Toolbar Icons"))
        } else {
            let header = NSMenuItem(title: "Toolbar Icons", action: nil, keyEquivalent: "")
            header.isEnabled = false
            items.append(header)
        }
        let sf = NSMenuItem(title: "SF Symbols", action: #selector(MenuTarget.setSFIcons(_:)), keyEquivalent: "")
        sf.target = MenuTarget.shared
        sf.state = MacToolbarIconMode.current == .systemSF ? .on : .off
        items.append(sf)
        let native = NSMenuItem(title: "In-game Icons", action: #selector(MenuTarget.setNativeIcons(_:)), keyEquivalent: "")
        native.target = MenuTarget.shared
        native.state = MacToolbarIconMode.current == .nativeInGame ? .on : .off
        items.append(native)
        return items
    }

    // MARK: - Builders

    private static func submenu(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        for child in items {
            menu.addItem(child)
        }
        item.submenu = menu
        return item
    }

    private static func submenuItem(_ title: String, children: [NSMenuItem]) -> NSMenuItem {
        submenu(title, items: children)
    }

    private static func command(
        _ title: String,
        widx: MacToolbarWIDX,
        extra: Int32,
        key: String = "",
        flags: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        command(title, code: widx.rawValue, extra: extra, key: key, flags: flags)
    }

    private static func command(
        _ title: String,
        code: Int32,
        extra: Int32 = 0,
        key: String = "",
        flags: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuBarTarget.invoke(_:)), keyEquivalent: key)
        item.target = MenuBarTarget.shared
        item.isEnabled = true
        item.representedObject = MenuBarCommand(code: code, extra: extra)
        if !key.isEmpty {
            item.keyEquivalentModifierMask = flags
        }
        return item
    }
}

private struct MenuBarCommand {
    let code: Int32
    let extra: Int32
}

@MainActor
final class MenuBarTarget: NSObject {
    static let shared = MenuBarTarget()
    var handler: ((Int32, Int32) -> Void)?

    @objc func invoke(_ sender: NSMenuItem) {
        guard let cmd = sender.representedObject as? MenuBarCommand else { return }
        handler?(cmd.code, cmd.extra)
    }
}
