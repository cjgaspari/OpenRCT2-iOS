/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Title-shell browsers: scenario select + load saved game.
 * Option A (CJ): clear NSPanel + NSGlassEffectView.contentView (.clear)
 * so park art shows through — not SwiftUI-only .glassEffect on opaque chrome.
 *****************************************************************************/

import AppKit
import SwiftUI

// MARK: - Clear Liquid Glass browser host (Option A)

enum MacGlassBrowserHost {
    @MainActor
    static func present(title: String, size: NSSize, root: some View) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
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
        panel.minSize = NSSize(width: 480, height: 320)

        // Content lives *inside* glass (WWDC25 310). Clear style samples park behind the window.
        let sizedRoot = root.frame(minWidth: size.width, minHeight: size.height)
        let host = NSHostingView(rootView: sizedRoot)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let glass = NSGlassEffectView()
        glass.style = .clear
        glass.cornerRadius = 18
        glass.contentView = host
        glass.frame = NSRect(origin: .zero, size: size)
        glass.autoresizingMask = [.width, .height]
        glass.wantsLayer = true

        panel.contentView = glass
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return panel
    }
}

// MARK: - C bridges

@_silgen_name("OpenRCT2MacNativeScenarioTabCount")
func OpenRCT2MacNativeScenarioTabCount() -> Int32
@_silgen_name("OpenRCT2MacNativeScenarioTabVisible")
func OpenRCT2MacNativeScenarioTabVisible(_ tab: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeScenarioTabName")
func OpenRCT2MacNativeScenarioTabName(_ tab: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeScenarioGetActiveTab")
func OpenRCT2MacNativeScenarioGetActiveTab() -> Int32
@_silgen_name("OpenRCT2MacNativeScenarioSetActiveTab")
func OpenRCT2MacNativeScenarioSetActiveTab(_ tab: Int32)
@_silgen_name("OpenRCT2MacNativeScenarioRowCount")
func OpenRCT2MacNativeScenarioRowCount() -> Int32
@_silgen_name("OpenRCT2MacNativeScenarioRowKind")
func OpenRCT2MacNativeScenarioRowKind(_ row: Int32) -> Int32 // 0 heading, 1 scenario
@_silgen_name("OpenRCT2MacNativeScenarioRowName")
func OpenRCT2MacNativeScenarioRowName(_ row: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeScenarioRowDetails")
func OpenRCT2MacNativeScenarioRowDetails(_ row: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeScenarioRowLocked")
func OpenRCT2MacNativeScenarioRowLocked(_ row: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeScenarioSelectRow")
func OpenRCT2MacNativeScenarioSelectRow(_ row: Int32) -> Bool

@_silgen_name("OpenRCT2MacNativeSaveFileCount")
func OpenRCT2MacNativeSaveFileCount() -> Int32
@_silgen_name("OpenRCT2MacNativeSaveFileGetName")
func OpenRCT2MacNativeSaveFileGetName(_ index: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeSaveFileGetDate")
func OpenRCT2MacNativeSaveFileGetDate(_ index: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeSaveFileLoad")
func OpenRCT2MacNativeSaveFileLoad(_ index: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeSaveFileRefresh")
func OpenRCT2MacNativeSaveFileRefresh()

// MARK: - Scenario select (3.20 / title)

enum MacScenarioSelectPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacGlassBrowserHost.present(
            title: "Select Scenario",
            size: NSSize(width: 720, height: 440),
            root: ScenarioSelectView {
                panel?.close()
                panel = nil
            }
        )
        return true
    }
}

private struct ScenarioSelectView: View {
    let onClose: () -> Void
    @State private var tab: Int = Int(OpenRCT2MacNativeScenarioGetActiveTab())
    @State private var selectedRow: Int?
    @State private var tick = 0

    private var visibleTabs: [(id: Int, name: String)] {
        let count = Int(OpenRCT2MacNativeScenarioTabCount())
        var tabs: [(Int, String)] = []
        for i in 0..<count {
            guard OpenRCT2MacNativeScenarioTabVisible(Int32(i)) else { continue }
            var buf = [CChar](repeating: 0, count: 128)
            OpenRCT2MacNativeScenarioTabName(Int32(i), &buf, buf.count)
            tabs.append((i, String(cString: buf)))
        }
        return tabs
    }

    private var rows: [ScenarioRow] {
        _ = tick
        let count = Int(OpenRCT2MacNativeScenarioRowCount())
        return (0..<count).map { i in
            var name = [CChar](repeating: 0, count: 256)
            var details = [CChar](repeating: 0, count: 512)
            OpenRCT2MacNativeScenarioRowName(Int32(i), &name, name.count)
            OpenRCT2MacNativeScenarioRowDetails(Int32(i), &details, details.count)
            return ScenarioRow(
                index: i,
                kind: OpenRCT2MacNativeScenarioRowKind(Int32(i)),
                name: String(cString: name),
                details: String(cString: details),
                locked: OpenRCT2MacNativeScenarioRowLocked(Int32(i))
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Scenario")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if !visibleTabs.isEmpty {
                Picker("", selection: $tab) {
                    ForEach(visibleTabs, id: \.id) { t in
                        Text(t.name).tag(t.id)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .padding(.horizontal, 12)
                .onChange(of: tab) { _, newValue in
                    OpenRCT2MacNativeScenarioSetActiveTab(Int32(newValue))
                    selectedRow = nil
                    tick &+= 1
                }
            }

            HStack(alignment: .top, spacing: 0) {
                List(selection: $selectedRow) {
                    ForEach(rows) { row in
                        if row.kind == 0 {
                            Text(row.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(row.locked ? .secondary : .primary)
                                if !row.details.isEmpty {
                                    Text(row.details)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .tag(row.index)
                            .opacity(row.locked ? 0.55 : 1)
                            .listRowBackground(
                                selectedRow == row.index
                                    ? Color.accentColor.opacity(0.22)
                                    : Color.white.opacity(0.06)
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minWidth: 360)

                VStack(alignment: .leading, spacing: 10) {
                    if let selectedRow, let row = rows.first(where: { $0.index == selectedRow && $0.kind == 1 }) {
                        Text(row.name)
                            .font(.headline)
                        if !row.details.isEmpty {
                            Text(row.details)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if row.locked {
                            Text("Locked — complete earlier scenarios to unlock.")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Button("Start Scenario") {
                            if OpenRCT2MacNativeScenarioSelectRow(Int32(row.index)) {
                                onClose()
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(row.locked)
                    } else {
                        Text("Choose a scenario")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(14)
                .frame(width: 240, alignment: .topLeading)
            }
            .padding(.top, 8)
        }
        // Glass is AppKit NSGlassEffectView (.clear); keep SwiftUI chrome transparent.
        .background(Color.clear)
        .onAppear {
            tab = Int(OpenRCT2MacNativeScenarioGetActiveTab())
            tick &+= 1
        }
    }
}

private struct ScenarioRow: Identifiable {
    var id: Int { index }
    let index: Int
    let kind: Int32
    let name: String
    let details: String
    let locked: Bool
}

@_cdecl("OpenRCT2MacNativeScenarioSelectShow")
func OpenRCT2MacNativeScenarioSelectShow() -> Bool {
    MainActor.assumeIsolated { MacScenarioSelectPanel.show() }
}

// MARK: - Load saved game (3.18 / title)

enum MacLoadParkPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        OpenRCT2MacNativeSaveFileRefresh()
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacGlassBrowserHost.present(
            title: "Load Saved Game",
            size: NSSize(width: 560, height: 400),
            root: LoadParkView {
                panel?.close()
                panel = nil
            }
        )
        return true
    }
}

private struct LoadParkView: View {
    let onClose: () -> Void
    @State private var selected: Int?
    @State private var files: [SaveFileRow] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Load Saved Game")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Refresh") {
                    OpenRCT2MacNativeSaveFileRefresh()
                    reload()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                Button("Close", action: onClose)
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(selection: $selected) {
                ForEach(files) { file in
                    HStack {
                        Text(file.name)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(file.date)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .tag(file.index)
                    .contentShape(Rectangle())
                    .listRowBackground(
                        selected == file.index
                            ? Color.accentColor.opacity(0.22)
                            : Color.white.opacity(0.06)
                    )
                    .onTapGesture(count: 2) {
                        if OpenRCT2MacNativeSaveFileLoad(Int32(file.index)) {
                            onClose()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)

            HStack {
                Text(files.isEmpty ? "No saved games found." : "\(files.count) save(s)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Load") {
                    if let selected, OpenRCT2MacNativeSaveFileLoad(Int32(selected)) {
                        onClose()
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .disabled(selected == nil)
            }
            .padding(12)
        }
        .background(Color.clear)
        .onAppear { reload() }
    }

    private func reload() {
        let count = Int(OpenRCT2MacNativeSaveFileCount())
        var next: [SaveFileRow] = []
        for i in 0..<count {
            var name = [CChar](repeating: 0, count: 256)
            var date = [CChar](repeating: 0, count: 128)
            OpenRCT2MacNativeSaveFileGetName(Int32(i), &name, name.count)
            OpenRCT2MacNativeSaveFileGetDate(Int32(i), &date, date.count)
            next.append(SaveFileRow(index: i, name: String(cString: name), date: String(cString: date)))
        }
        files = next
    }
}

private struct SaveFileRow: Identifiable {
    var id: Int { index }
    let index: Int
    let name: String
    let date: String
}

@_cdecl("OpenRCT2MacNativeLoadParkShow")
func OpenRCT2MacNativeLoadParkShow() -> Bool {
    MainActor.assumeIsolated { MacLoadParkPanel.show() }
}
