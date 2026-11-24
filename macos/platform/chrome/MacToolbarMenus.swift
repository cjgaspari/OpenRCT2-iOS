/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * NSMenu mirrors of classic TopToolbar dropdowns — same items / indices as
 * TopToolbar.cpp (FileMenuDdidx, ViewMenu, etc.). Labels are English stand-ins
 * for STR_* until localization bridge lands; order/indices stay 1:1.
 *****************************************************************************/

import AppKit

@_silgen_name("OpenRCT2MacNativeViewMenuIsChecked")
func OpenRCT2MacNativeViewMenuIsChecked(_ ddidx: Int32) -> Bool

/// View-menu toggle indices that show a macOS checkmark when on (HIG).
enum MacViewMenuCheckmarks {
    /// Matches TopToolbar setChecked list (not Transparency Options…).
    static let toggleIndices: Set<Int32> = [
        0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 18, 19,
    ]

    static func state(for ddidx: Int32) -> NSControl.StateValue {
        guard toggleIndices.contains(ddidx) else { return .off }
        return OpenRCT2MacNativeViewMenuIsChecked(ddidx) ? .on : .off
    }

    /// Rebuild checkmarks when the toolbar View pop-up uses Int32 dropdown indices.
    static func applyToolbarIndices(to menu: NSMenu) {
        for item in menu.items {
            guard let index = item.representedObject as? Int32 else { continue }
            item.state = state(for: index)
        }
    }
}

enum MacToolbarIconMode: String {
    case systemSF = "sf"
    case nativeInGame = "native"

    static let defaultsKey = "openrct2.mac.glass.iconMode"

    static var current: MacToolbarIconMode {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? MacToolbarIconMode.nativeInGame.rawValue
            return MacToolbarIconMode(rawValue: raw) ?? .nativeInGame
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}

@MainActor
enum MacToolbarMenus {
    /// Dropdown-bearing classic widgets — show NSMenu instead of a primary shortcut.
    static func isMenuWidget(_ widx: MacToolbarWIDX) -> Bool {
        switch widx {
        case .fileMenu, .fastForward, .viewMenu, .map, .cheats, .debug, .network:
            return true
        default:
            return false
        }
    }

    static func popUp(
        for widx: MacToolbarWIDX,
        relativeTo view: NSView?,
        onSelect: @escaping (Int32) -> Void
    ) {
        let menu = buildMenu(for: widx, onSelect: onSelect)
        if let view {
            let point = NSPoint(x: 0, y: view.bounds.height)
            menu.popUp(positioning: nil, at: point, in: view)
        } else if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }

    private static func buildMenu(for widx: MacToolbarWIDX, onSelect: @escaping (Int32) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        func item(_ title: String, index: Int32, enabled: Bool = true, state: NSControl.StateValue = .off) {
            let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            it.isEnabled = enabled
            it.state = state
            it.representedObject = index
            it.target = MenuTarget.shared
            it.action = #selector(MenuTarget.selected(_:))
            MenuTarget.shared.handler = onSelect
            menu.addItem(it)
        }

        func sep() { menu.addItem(.separator()) }

        switch widx {
        case .fileMenu:
            // FileMenuDdidx — normal game
            item("New Game", index: 0)
            item("Load Game", index: 1)
            sep()
            item("Save Game", index: 3)
            item("Save Game As…", index: 4)
            sep()
            item("Screenshot", index: 6)
            item("Giant Screenshot", index: 7)
            sep()
            item("About OpenRCT2", index: 9)
            item("File Bug on GitHub", index: 10)
            item("Options…", index: 12)
            // Mac-only: inline (not nested submenu) so it always appears in
            // toolbar File popUp — nested submenus were missing under popUp.
            sep()
            addToolbarIconsSection(to: menu)
            sep()
            item("Quit to Menu", index: 14)
            item("Exit OpenRCT2", index: 15)

        case .fastForward:
            item("Normal Speed", index: 0)
            item("Quick Speed", index: 1)
            item("Fast Speed", index: 2)
            item("Turbo Speed", index: 3)
            sep()
            item("Hyper Speed", index: 5)

        case .viewMenu:
            // TopToolbarViewMenuDdidx — rebuild checkmarks from live viewport on open.
            item("Underground View", index: 0, state: MacViewMenuCheckmarks.state(for: 0))
            item("Transparent Water", index: 1, state: MacViewMenuCheckmarks.state(for: 1))
            item("Remove Base Land", index: 2, state: MacViewMenuCheckmarks.state(for: 2))
            item("Remove Vertical Faces", index: 3, state: MacViewMenuCheckmarks.state(for: 3))
            sep()
            item("See-through Rides", index: 5, state: MacViewMenuCheckmarks.state(for: 5))
            item("See-through Vehicles", index: 6, state: MacViewMenuCheckmarks.state(for: 6))
            item("See-through Vegetation", index: 7, state: MacViewMenuCheckmarks.state(for: 7))
            item("See-through Scenery", index: 8, state: MacViewMenuCheckmarks.state(for: 8))
            item("See-through Paths", index: 9, state: MacViewMenuCheckmarks.state(for: 9))
            item("See-through Supports", index: 10, state: MacViewMenuCheckmarks.state(for: 10))
            item("See-through Guests", index: 11, state: MacViewMenuCheckmarks.state(for: 11))
            item("See-through Staff", index: 12, state: MacViewMenuCheckmarks.state(for: 12))
            sep()
            item("Height Marks on Land", index: 14, state: MacViewMenuCheckmarks.state(for: 14))
            item("Height Marks on Tracks", index: 15, state: MacViewMenuCheckmarks.state(for: 15))
            item("Height Marks on Paths", index: 16, state: MacViewMenuCheckmarks.state(for: 16))
            sep()
            item("View Clipping…", index: 18, state: MacViewMenuCheckmarks.state(for: 18))
            item("Highlight Path Issues", index: 19, state: MacViewMenuCheckmarks.state(for: 19))
            sep()
            item("Transparency Options…", index: 21)

        case .map:
            item("Show Map", index: 0)
            item("Extra Viewport", index: 1)

        case .cheats:
            item("Cheats…", index: 0)
            item("Tile Inspector…", index: 1)
            item("Object Selection…", index: 2)
            item("Inventions List…", index: 3)
            item("Scenario Options…", index: 4)
            sep()
            item("Enable Sandbox Mode", index: 6)
            item("Disable Clearance Checks", index: 7)
            item("Disable Support Limits", index: 8)

        case .debug:
            item("Console", index: 0)
            item("Debug Paint", index: 1)

        case .network:
            item("Multiplayer…", index: 0)
            item("Reconnect", index: 1)

        default:
            break
        }

        return menu
    }

    /// Mac-only icon mode toggle. Kept as top-level File items (section header +
    /// radio rows) because nested `NSMenu` submenus do not reliably appear when
    /// the File menu is shown via `NSMenu.popUp(positioning:at:in:)`.
    private static func addToolbarIconsSection(to menu: NSMenu) {
        if #available(macOS 14.0, *) {
            menu.addItem(.sectionHeader(title: "Toolbar Icons"))
        } else {
            let header = NSMenuItem(title: "Toolbar Icons", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }

        let sf = NSMenuItem(
            title: "SF Symbols",
            action: #selector(MenuTarget.setSFIcons(_:)),
            keyEquivalent: ""
        )
        sf.target = MenuTarget.shared
        sf.isEnabled = true
        sf.state = MacToolbarIconMode.current == .systemSF ? .on : .off
        menu.addItem(sf)

        let native = NSMenuItem(
            title: "In-game Icons",
            action: #selector(MenuTarget.setNativeIcons(_:)),
            keyEquivalent: ""
        )
        native.target = MenuTarget.shared
        native.isEnabled = true
        native.state = MacToolbarIconMode.current == .nativeInGame ? .on : .off
        menu.addItem(native)
    }
}

@MainActor
final class MenuTarget: NSObject {
    static let shared = MenuTarget()
    var handler: ((Int32) -> Void)?
    var onIconModeChanged: (() -> Void)?

    @objc func selected(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int32 else { return }
        handler?(index)
    }

    @objc func setSFIcons(_ sender: NSMenuItem) {
        MacToolbarIconMode.current = .systemSF
        onIconModeChanged?()
    }

    @objc func setNativeIcons(_ sender: NSMenuItem) {
        MacToolbarIconMode.current = .nativeInGame
        onIconModeChanged?()
    }
}
