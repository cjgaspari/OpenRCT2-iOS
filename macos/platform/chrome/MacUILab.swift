/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * UI Lab — per-surface native vs classic engine toggles + loading preference.
 * Persisted in UserDefaults. Hotkey: ⌥⌘U.
 * Rule: every native surface MUST have a toggle (incl. title/startup).
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacUISurface: String, CaseIterable, Identifiable {
    // Title & chrome
    case titleStartup
    case parkChrome
    case menuBar
    // Dialogs / toasts
    case alerts
    case progress
    case news
    // Browsers
    case scenarioSelect
    case loadPark
    // Panels / windows
    case options
    case cheats
    case about
    case themes
    case shortcuts
    case assetPacks
    case viewClipping
    case customCurrency
    case changelog
    case networkStatus
    case newCampaign
    case objectLoadError
    case debugPaint
    case transparency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .titleStartup: return "Title / startup"
        case .parkChrome: return "Park glass HUD"
        case .menuBar: return "macOS menu bar"
        case .alerts: return "Alerts / confirms"
        case .progress: return "Progress / loading"
        case .news: return "Recent news"
        case .scenarioSelect: return "Scenario select"
        case .loadPark: return "Load saved game"
        case .options: return "Options"
        case .cheats: return "Cheats"
        case .about: return "About"
        case .themes: return "Themes"
        case .shortcuts: return "Shortcut keys"
        case .assetPacks: return "Asset packs"
        case .viewClipping: return "View clipping"
        case .customCurrency: return "Custom currency"
        case .changelog: return "Changelog"
        case .networkStatus: return "Network status"
        case .newCampaign: return "New campaign"
        case .objectLoadError: return "Object load error"
        case .debugPaint: return "Debug paint"
        case .transparency: return "Transparency"
        }
    }

    var group: String {
        switch self {
        case .titleStartup, .parkChrome, .menuBar:
            return "Title & chrome"
        case .alerts, .progress, .news:
            return "Dialogs"
        case .scenarioSelect, .loadPark:
            return "Browsers"
        default:
            return "Panels"
        }
    }

    /// Default: native on, except progress prefers classic in-game indicator.
    var defaultNative: Bool {
        self != .progress
    }
}

@_silgen_name("OpenRCT2MacUINotifySurfaceChanged")
func OpenRCT2MacUINotifySurfaceChanged(_ surfaceId: UnsafePointer<CChar>)

enum MacNewsToastEdge: String, CaseIterable, Identifiable {
    case bottom
    case top

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: return "Bottom"
        case .top: return "Top"
        }
    }
}

@MainActor
@Observable
final class MacUILabPrefs {
    static let shared = MacUILabPrefs()

    private let defaults = UserDefaults.standard
    private let prefix = "openrct2.mac.ui.native."
    private let toastEdgeKey = "openrct2.mac.ui.newsToastEdge"

    /// When true, ProgressPresent falls back to classic engine window (CJ default).
    var preferClassicProgress: Bool {
        didSet { defaults.set(preferClassicProgress, forKey: prefix + "preferClassicProgress") }
    }

    /// News / error toast edge on the park glass HUD.
    var newsToastEdge: MacNewsToastEdge {
        didSet {
            defaults.set(newsToastEdge.rawValue, forKey: toastEdgeKey)
            NotificationCenter.default.post(name: .openRCT2MacChromePrefsDidChange, object: nil)
        }
    }

    /// Liquid Glass HUD size. 1.0 = current default (smallest); independent of classic `window_scale`.
    var glassChromeScale: Double {
        didSet {
            let clamped = Self.clampGlassScale(glassChromeScale)
            if clamped != glassChromeScale {
                glassChromeScale = clamped
                return
            }
            defaults.set(glassChromeScale, forKey: glassScaleKey)
            NotificationCenter.default.post(name: .openRCT2MacChromePrefsDidChange, object: nil)
        }
    }

    private let glassScaleKey = "openrct2.mac.ui.glassChromeScale"

    private var nativeBySurface: [String: Bool]

    static func clampGlassScale(_ value: Double) -> Double {
        min(2.0, max(1.0, (value * 4.0).rounded() / 4.0))
    }

    init() {
        var map: [String: Bool] = [:]
        for surface in MacUISurface.allCases {
            let key = prefix + surface.rawValue
            if defaults.object(forKey: key) == nil {
                defaults.set(surface.defaultNative, forKey: key)
            }
            map[surface.rawValue] = defaults.bool(forKey: key)
        }
        nativeBySurface = map
        if defaults.object(forKey: prefix + "preferClassicProgress") == nil {
            defaults.set(true, forKey: prefix + "preferClassicProgress")
        }
        preferClassicProgress = defaults.bool(forKey: prefix + "preferClassicProgress")
        if let raw = defaults.string(forKey: toastEdgeKey),
           let edge = MacNewsToastEdge(rawValue: raw)
        {
            newsToastEdge = edge
        } else {
            newsToastEdge = .bottom
        }
        if defaults.object(forKey: glassScaleKey) == nil {
            glassChromeScale = 1.0
        } else {
            glassChromeScale = Self.clampGlassScale(defaults.double(forKey: glassScaleKey))
        }
    }

    func isNativeEnabled(_ surface: MacUISurface) -> Bool {
        if surface == .progress, preferClassicProgress {
            return false
        }
        return nativeBySurface[surface.rawValue] ?? surface.defaultNative
    }

    func binding(for surface: MacUISurface) -> Binding<Bool> {
        Binding(
            get: { self.nativeBySurface[surface.rawValue] ?? surface.defaultNative },
            set: { newValue in
                self.nativeBySurface[surface.rawValue] = newValue
                self.defaults.set(newValue, forKey: self.prefix + surface.rawValue)
                if surface == .menuBar {
                    MacMenuBar.setEnabled(newValue)
                }
                surface.rawValue.withCString { OpenRCT2MacUINotifySurfaceChanged($0) }
            }
        )
    }

    func resetDefaults() {
        for surface in MacUISurface.allCases {
            nativeBySurface[surface.rawValue] = surface.defaultNative
            defaults.set(surface.defaultNative, forKey: prefix + surface.rawValue)
            surface.rawValue.withCString { OpenRCT2MacUINotifySurfaceChanged($0) }
        }
        preferClassicProgress = true
        newsToastEdge = .bottom
        glassChromeScale = 1.0
    }
}

enum MacUILab {
    @MainActor private static var panel: NSPanel?
    @MainActor private static var hotkeyInstalled = false

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "UI Lab"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 360)

        let host = NSHostingView(rootView: UILabView {
            panel.close()
            Self.panel = nil
        })
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Self.panel = panel
        installHotkeyIfNeeded()
        return true
    }

    @MainActor
    static func installHotkeyIfNeeded() {
        guard !hotkeyInstalled else { return }
        hotkeyInstalled = true
        MacGlassStyleLab.installHotkeyIfNeeded()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌥⌘U
            if event.modifierFlags.contains([.command, .option]),
               event.charactersIgnoringModifiers?.lowercased() == "u"
            {
                _ = show()
                return nil
            }
            return event
        }
    }
}

private struct UILabView: View {
    let onClose: () -> Void
    @Bindable private var prefs = MacUILabPrefs.shared

    private var grouped: [(String, [MacUISurface])] {
        let order = ["Title & chrome", "Dialogs", "Browsers", "Panels"]
        let dict = Dictionary(grouping: MacUISurface.allCases, by: \.group)
        return order.compactMap { key in
            guard let items = dict[key] else { return nil }
            return (key, items)
        }
    }

    private var glassScaleControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Glass UI size")
                Spacer()
                Text("\(Int((prefs.glassChromeScale * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.caption)
            Slider(
                value: $prefs.glassChromeScale,
                in: 1.0...2.0,
                step: 0.25
            )
            .controlSize(.small)
            Text("1.0× is the default (smallest). Independent of classic window scale.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UI Lab")
                        .font(.title3.weight(.semibold))
                    Text("Every native surface can revert to classic. Persisted. ⌥⌘U.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Loading") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Prefer classic in-game progress (default)", isOn: $prefs.preferClassicProgress)
                            .controlSize(.small)
                        Text("When on, Progress/loading uses the engine window instead of the macOS spinner.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("Park glass HUD") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("News toast", selection: $prefs.newsToastEdge) {
                            ForEach(MacNewsToastEdge.allCases) { edge in
                                Text(edge.title).tag(edge)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        glassScaleControls
                        Text("Toolbar icons: Options → Interface (full list). Scale is separate from classic window_scale.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                ForEach(grouped, id: \.0) { group, surfaces in
                    GroupBox(group) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(surfaces) { surface in
                                Toggle(surface.title, isOn: prefs.binding(for: surface))
                                    .controlSize(.small)
                                    .disabled(surface == .progress && prefs.preferClassicProgress)
                            }
                        }
                        .padding(6)
                    }
                }

                // Close = traffic lights only.
                HStack {
                    Button("Reset defaults") { prefs.resetDefaults() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Glass Style Lab…") { _ = MacGlassStyleLab.show() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@_cdecl("OpenRCT2MacNativeUILabShow")
func OpenRCT2MacNativeUILabShow() -> Bool {
    MainActor.assumeIsolated { MacUILab.show() }
}

/// C++ Present gates — return false to use classic engine UI.
/// Safe from any thread (JobPool / BackgroundWorker call this during load).
@_cdecl("OpenRCT2MacUINativeEnabled")
func OpenRCT2MacUINativeEnabled(_ surfaceId: UnsafePointer<CChar>?) -> Bool {
    guard let surfaceId else { return true }
    let id = String(cString: surfaceId)
    let prefix = "openrct2.mac.ui.native."
    let defaults = UserDefaults.standard

    // Progress: classic preferred by default (mirrors MacUILabPrefs).
    if id == "progress" {
        if defaults.object(forKey: prefix + "preferClassicProgress") == nil
            || defaults.bool(forKey: prefix + "preferClassicProgress")
        {
            return false
        }
    }

    let key = prefix + id
    if defaults.object(forKey: key) == nil {
        // Default native on for every surface except progress.
        return id != "progress"
    }
    return defaults.bool(forKey: key)
}
