/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Dense classic-Mac content panels (Tier 2). Standard window materials —
 * Liquid Glass stays on park chrome / toasts only (HIG Materials).
 *****************************************************************************/

import AppKit
import SwiftUI

// MARK: - C bridge (implemented in MacNativeUI.mm)

@_silgen_name("OpenRCT2MacNativeDebugPaintGet")
func OpenRCT2MacNativeDebugPaintGet(_ flag: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeDebugPaintSet")
func OpenRCT2MacNativeDebugPaintSet(_ flag: Int32, _ value: Bool)
@_silgen_name("OpenRCT2MacNativeTransparencyGet")
func OpenRCT2MacNativeTransparencyGet() -> UInt32
@_silgen_name("OpenRCT2MacNativeTransparencyToggle")
func OpenRCT2MacNativeTransparencyToggle(_ flag: UInt32)

// MARK: - Shared dense panel chrome

enum MacDensePanelHost {
    @MainActor
    static func present(title: String, size: NSSize, root: some View) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.center()
        // Keep clear of Option 1 top glass (~72px engine inset ≈ panel nudge).
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

// MARK: - Debug Paint (2.10)

enum MacDebugPaintPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Debug Paint",
            size: NSSize(width: 260, height: 220),
            root: DebugPaintView()
        )
        return true
    }
}

private struct DebugPaintView: View {
    @State private var flags: [Bool] = (0..<7).map { OpenRCT2MacNativeDebugPaintGet(Int32($0)) }

    private let labels = [
        "Show wide paths as ghost",
        "Show blocked tiles",
        "Show segment heights",
        "Show bound boxes",
        "Show dirty visuals",
        "Stable paint sort",
        "Force redraw",
    ]

    var body: some View {
        Form {
            ForEach(labels.indices, id: \.self) { i in
                Toggle(labels[i], isOn: binding(i))
                    .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func binding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { flags[index] },
            set: { newValue in
                flags[index] = newValue
                OpenRCT2MacNativeDebugPaintSet(Int32(index), newValue)
            }
        )
    }
}

// MARK: - Transparency (2.8)

enum MacTransparencyPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Transparency Options",
            size: NSSize(width: 320, height: 280),
            root: TransparencyView()
        )
        return true
    }
}

private struct TransparencyView: View {
    @State private var mask: UInt32 = OpenRCT2MacNativeTransparencyGet()

    private struct Row: Identifiable {
        let id: UInt32
        let title: String
    }

    private let seeThrough: [Row] = [
        .init(id: 1 << 0, title: "See-through vegetation"),
        .init(id: 1 << 1, title: "See-through scenery"),
        .init(id: 1 << 2, title: "See-through paths"),
        .init(id: 1 << 3, title: "See-through rides"),
        .init(id: 1 << 4, title: "See-through vehicles"),
        .init(id: 1 << 5, title: "See-through supports"),
        .init(id: 1 << 6, title: "See-through guests"),
        .init(id: 1 << 7, title: "See-through staff"),
    ]

    private let invisible: [Row] = [
        .init(id: 1 << 8, title: "Invisible vegetation"),
        .init(id: 1 << 9, title: "Invisible scenery"),
        .init(id: 1 << 10, title: "Invisible paths"),
        .init(id: 1 << 11, title: "Invisible rides"),
        .init(id: 1 << 12, title: "Invisible vehicles"),
        .init(id: 1 << 13, title: "Invisible supports"),
    ]

    var body: some View {
        Form {
            Section("See-through") {
                ForEach(seeThrough) { row in
                    Toggle(row.title, isOn: flagBinding(row.id))
                        .controlSize(.small)
                }
            }
            Section("Invisible") {
                ForEach(invisible) { row in
                    Toggle(row.title, isOn: flagBinding(row.id))
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { mask = OpenRCT2MacNativeTransparencyGet() }
    }

    private func flagBinding(_ flag: UInt32) -> Binding<Bool> {
        Binding(
            get: { (mask & flag) != 0 },
            set: { _ in
                OpenRCT2MacNativeTransparencyToggle(flag)
                mask = OpenRCT2MacNativeTransparencyGet()
            }
        )
    }
}

// MARK: - C exports

@_cdecl("OpenRCT2MacNativeDebugPaintShow")
func OpenRCT2MacNativeDebugPaintShow() -> Bool {
    MainActor.assumeIsolated { MacDebugPaintPanel.show() }
}

@_cdecl("OpenRCT2MacNativeTransparencyShow")
func OpenRCT2MacNativeTransparencyShow() -> Bool {
    MainActor.assumeIsolated { MacTransparencyPanel.show() }
}

// MARK: - Custom Currency (2.4)

@_silgen_name("OpenRCT2MacNativeCustomCurrencyGetRate")
func OpenRCT2MacNativeCustomCurrencyGetRate() -> Int32
@_silgen_name("OpenRCT2MacNativeCustomCurrencySetRate")
func OpenRCT2MacNativeCustomCurrencySetRate(_ rate: Int32)
@_silgen_name("OpenRCT2MacNativeCustomCurrencyGetSymbol")
func OpenRCT2MacNativeCustomCurrencyGetSymbol(_ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeCustomCurrencySetSymbol")
func OpenRCT2MacNativeCustomCurrencySetSymbol(_ symbol: UnsafePointer<CChar>?)
@_silgen_name("OpenRCT2MacNativeCustomCurrencyGetAffix")
func OpenRCT2MacNativeCustomCurrencyGetAffix() -> Int32
@_silgen_name("OpenRCT2MacNativeCustomCurrencySetAffix")
func OpenRCT2MacNativeCustomCurrencySetAffix(_ affix: Int32)

enum MacCustomCurrencyPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Custom Currency",
            size: NSSize(width: 360, height: 160),
            root: CustomCurrencyView()
        )
        return true
    }
}

private struct CustomCurrencyView: View {
    @State private var rate: Double = Double(OpenRCT2MacNativeCustomCurrencyGetRate())
    @State private var symbol: String = {
        var buf = [CChar](repeating: 0, count: 32)
        OpenRCT2MacNativeCustomCurrencyGetSymbol(&buf, buf.count)
        return String(cString: buf)
    }()
    @State private var affix: Int = Int(OpenRCT2MacNativeCustomCurrencyGetAffix())

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Rate")
                    Spacer()
                    Stepper(value: $rate, in: 1...9999, step: 1) {
                        Text("\(Int(rate))")
                            .monospacedDigit()
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                    .controlSize(.small)
                    .onChange(of: rate) { _, newValue in
                        OpenRCT2MacNativeCustomCurrencySetRate(Int32(newValue))
                    }
                }
                TextField("Symbol", text: $symbol)
                    .controlSize(.small)
                    .onSubmit {
                        OpenRCT2MacNativeCustomCurrencySetSymbol(symbol)
                    }
                    .onChange(of: symbol) { _, newValue in
                        OpenRCT2MacNativeCustomCurrencySetSymbol(newValue)
                    }
                Picker("Affix", selection: $affix) {
                    Text("Prefix").tag(0)
                    Text("Suffix").tag(1)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .onChange(of: affix) { _, newValue in
                    OpenRCT2MacNativeCustomCurrencySetAffix(Int32(newValue))
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@_cdecl("OpenRCT2MacNativeCustomCurrencyShow")
func OpenRCT2MacNativeCustomCurrencyShow() -> Bool {
    MainActor.assumeIsolated { MacCustomCurrencyPanel.show() }
}

// MARK: - Changelog (2.6)

@_silgen_name("OpenRCT2MacNativeChangelogGetText")
func OpenRCT2MacNativeChangelogGetText(_ personality: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int) -> Bool

enum MacChangelogPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show(personality: Int32) -> Bool {
        var buf = [CChar](repeating: 0, count: 512 * 1024)
        guard OpenRCT2MacNativeChangelogGetText(personality, &buf, buf.count) else { return false }
        let text = String(cString: buf)
        let title: String
        switch personality {
        case 1: title = "Contributors"
        case 2: title = "New Version"
        default: title = "Changelog"
        }
        if let panel, panel.isVisible {
            panel.title = title
            panel.makeKeyAndOrderFront(nil)
        }
        panel = MacDensePanelHost.present(
            title: title,
            size: NSSize(width: 560, height: 420),
            root: ChangelogView(text: text)
        )
        return true
    }
}

private struct ChangelogView: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@_cdecl("OpenRCT2MacNativeChangelogShow")
func OpenRCT2MacNativeChangelogShow(_ personality: Int32) -> Bool {
    MainActor.assumeIsolated { MacChangelogPanel.show(personality: personality) }
}

// MARK: - Progress / Network status (1.12 / 1.13)

enum MacProgressPanel {
    @MainActor private static var panel: NSPanel?
    @MainActor private static var model = ProgressModel()

    @MainActor
    static func show(_ text: String) -> Bool {
        model.caption = text
        model.current = 0
        model.total = 0
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Progress",
            size: NSSize(width: 400, height: 90),
            root: ProgressStatusView(model: model)
        )
        return true
    }

    @MainActor
    static func set(current: UInt32, total: UInt32) {
        model.current = current
        model.total = total
    }

    @MainActor
    static func close() {
        panel?.close()
        panel = nil
    }
}

enum MacNetworkStatusPanel {
    @MainActor private static var panel: NSPanel?
    @MainActor private static var model = ProgressModel()

    @MainActor
    static func show(_ text: String) -> Bool {
        model.caption = text
        model.current = 0
        model.total = 0
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Network",
            size: NSSize(width: 400, height: 90),
            root: ProgressStatusView(model: model)
        )
        return true
    }

    @MainActor
    static func close() {
        panel?.close()
        panel = nil
    }
}

@Observable
private final class ProgressModel {
    var caption: String = ""
    var current: UInt32 = 0
    var total: UInt32 = 0
}

private struct ProgressStatusView: View {
    @Bindable var model: ProgressModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.caption)
                .font(.system(size: 12))
                .lineLimit(2)
            if model.total > 0 {
                ProgressView(value: Double(model.current), total: Double(model.total))
                    .controlSize(.small)
                Text("\(model.current) of \(model.total)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@_cdecl("OpenRCT2MacNativeProgressShow")
func OpenRCT2MacNativeProgressShow(_ text: UnsafePointer<CChar>?) -> Bool {
    let t = text.map { String(cString: $0) } ?? "Working…"
    return MainActor.assumeIsolated { MacProgressPanel.show(t) }
}

@_cdecl("OpenRCT2MacNativeProgressSetUI")
func OpenRCT2MacNativeProgressSetUI(_ current: UInt32, _ total: UInt32) {
    MainActor.assumeIsolated { MacProgressPanel.set(current: current, total: total) }
}

@_cdecl("OpenRCT2MacNativeProgressCloseUI")
func OpenRCT2MacNativeProgressCloseUI() {
    MainActor.assumeIsolated { MacProgressPanel.close() }
}

@_cdecl("OpenRCT2MacNativeNetworkStatusShow")
func OpenRCT2MacNativeNetworkStatusShow(_ text: UnsafePointer<CChar>?) -> Bool {
    let t = text.map { String(cString: $0) } ?? ""
    return MainActor.assumeIsolated { MacNetworkStatusPanel.show(t) }
}

@_cdecl("OpenRCT2MacNativeNetworkStatusCloseUI")
func OpenRCT2MacNativeNetworkStatusCloseUI() {
    MainActor.assumeIsolated { MacNetworkStatusPanel.close() }
}

// MARK: - View Clipping (2.9)

@_silgen_name("OpenRCT2MacNativeViewClippingGetEnabled")
func OpenRCT2MacNativeViewClippingGetEnabled() -> Bool
@_silgen_name("OpenRCT2MacNativeViewClippingSetEnabled")
func OpenRCT2MacNativeViewClippingSetEnabled(_ enabled: Bool)
@_silgen_name("OpenRCT2MacNativeViewClippingGetSeeThrough")
func OpenRCT2MacNativeViewClippingGetSeeThrough() -> Bool
@_silgen_name("OpenRCT2MacNativeViewClippingSetSeeThrough")
func OpenRCT2MacNativeViewClippingSetSeeThrough(_ enabled: Bool)
@_silgen_name("OpenRCT2MacNativeViewClippingGetHeight")
func OpenRCT2MacNativeViewClippingGetHeight() -> Int32
@_silgen_name("OpenRCT2MacNativeViewClippingSetHeight")
func OpenRCT2MacNativeViewClippingSetHeight(_ height: Int32)
@_silgen_name("OpenRCT2MacNativeViewClippingClearSelection")
func OpenRCT2MacNativeViewClippingClearSelection()

enum MacViewClippingPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        OpenRCT2MacNativeViewClippingSetEnabled(true)
        panel = MacDensePanelHost.present(
            title: "View Clipping",
            size: NSSize(width: 280, height: 180),
            root: ViewClippingView()
        )
        return true
    }
}

private struct ViewClippingView: View {
    @State private var enabled = OpenRCT2MacNativeViewClippingGetEnabled()
    @State private var seeThrough = OpenRCT2MacNativeViewClippingGetSeeThrough()
    @State private var height: Double = Double(OpenRCT2MacNativeViewClippingGetHeight())

    var body: some View {
        Form {
            Toggle("Enable height clipping", isOn: $enabled)
                .controlSize(.small)
                .onChange(of: enabled) { _, v in OpenRCT2MacNativeViewClippingSetEnabled(v) }
            Section("Vertical") {
                HStack {
                    Text("Height")
                    Slider(value: $height, in: 0...255, step: 1)
                        .controlSize(.small)
                        .onChange(of: height) { _, v in OpenRCT2MacNativeViewClippingSetHeight(Int32(v)) }
                    Text("\(Int(height))")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                }
                Toggle("See-through", isOn: $seeThrough)
                    .controlSize(.small)
                    .onChange(of: seeThrough) { _, v in OpenRCT2MacNativeViewClippingSetSeeThrough(v) }
            }
            Section("Horizontal") {
                Button("Clear Selection") {
                    OpenRCT2MacNativeViewClippingClearSelection()
                }
                .controlSize(.small)
                Text("Select Area stays on the park map (engine tool).")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            enabled = OpenRCT2MacNativeViewClippingGetEnabled()
            seeThrough = OpenRCT2MacNativeViewClippingGetSeeThrough()
            height = Double(OpenRCT2MacNativeViewClippingGetHeight())
        }
    }
}

@_cdecl("OpenRCT2MacNativeViewClippingShow")
func OpenRCT2MacNativeViewClippingShow() -> Bool {
    MainActor.assumeIsolated { MacViewClippingPanel.show() }
}

// MARK: - Asset Packs (2.5)

@_silgen_name("OpenRCT2MacNativeAssetPackCount")
func OpenRCT2MacNativeAssetPackCount() -> Int32
@_silgen_name("OpenRCT2MacNativeAssetPackGetName")
func OpenRCT2MacNativeAssetPackGetName(_ index: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeAssetPackGetEnabled")
func OpenRCT2MacNativeAssetPackGetEnabled(_ index: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeAssetPackSetEnabled")
func OpenRCT2MacNativeAssetPackSetEnabled(_ index: Int32, _ enabled: Bool)
@_silgen_name("OpenRCT2MacNativeAssetPackMove")
func OpenRCT2MacNativeAssetPackMove(_ index: Int32, _ direction: Int32)
@_silgen_name("OpenRCT2MacNativeAssetPackApply")
func OpenRCT2MacNativeAssetPackApply()

enum MacAssetPacksPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Asset Packs",
            size: NSSize(width: 420, height: 280),
            root: AssetPacksView()
        )
        return true
    }
}

private struct AssetPacksView: View {
    @State private var names: [String] = []
    @State private var enabled: [Bool] = []
    @State private var selected: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            Text("High priority")
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            List(selection: $selected) {
                ForEach(names.indices, id: \.self) { i in
                    HStack {
                        Toggle("", isOn: binding(i))
                            .labelsHidden()
                            .controlSize(.small)
                        Text(names[i])
                            .font(.system(size: 11))
                    }
                    .tag(i)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            Text("Low priority")
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("Move Up") { move(-1) }.controlSize(.small)
                Button("Move Down") { move(1) }.controlSize(.small)
                Spacer()
                Button("Apply") {
                    OpenRCT2MacNativeAssetPackApply()
                    reload()
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .onAppear { reload() }
        .onDisappear { OpenRCT2MacNativeAssetPackApply() }
    }

    private func binding(_ i: Int) -> Binding<Bool> {
        Binding(
            get: { enabled.indices.contains(i) ? enabled[i] : false },
            set: { v in
                guard enabled.indices.contains(i) else { return }
                enabled[i] = v
                OpenRCT2MacNativeAssetPackSetEnabled(Int32(i), v)
            }
        )
    }

    private func move(_ dir: Int) {
        OpenRCT2MacNativeAssetPackMove(Int32(selected), Int32(dir))
        selected = max(0, min(names.count - 1, selected + dir))
        reload()
    }

    private func reload() {
        let count = Int(OpenRCT2MacNativeAssetPackCount())
        var n: [String] = []
        var e: [Bool] = []
        for i in 0..<count {
            var buf = [CChar](repeating: 0, count: 256)
            OpenRCT2MacNativeAssetPackGetName(Int32(i), &buf, buf.count)
            n.append(String(cString: buf))
            e.append(OpenRCT2MacNativeAssetPackGetEnabled(Int32(i)))
        }
        names = n
        enabled = e
    }
}

@_cdecl("OpenRCT2MacNativeAssetPacksShow")
func OpenRCT2MacNativeAssetPacksShow() -> Bool {
    MainActor.assumeIsolated { MacAssetPacksPanel.show() }
}
