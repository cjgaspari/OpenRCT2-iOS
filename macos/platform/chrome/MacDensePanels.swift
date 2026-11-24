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
