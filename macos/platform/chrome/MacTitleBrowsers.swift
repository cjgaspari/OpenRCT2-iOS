/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Title-shell browsers: scenario select + load saved game.
 * Mid-legibility: clear NSGlassEffectView + localized dark dimming (~0.35) +
 * vibrant dark-scheme labels. Classic park preview in the detail pane.
 *****************************************************************************/

import AppKit
import SwiftUI

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
func OpenRCT2MacNativeScenarioRowKind(_ row: Int32) -> Int32
@_silgen_name("OpenRCT2MacNativeScenarioRowName")
func OpenRCT2MacNativeScenarioRowName(_ row: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeScenarioRowDetails")
func OpenRCT2MacNativeScenarioRowDetails(_ row: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeScenarioRowLocked")
func OpenRCT2MacNativeScenarioRowLocked(_ row: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeScenarioSelectRow")
func OpenRCT2MacNativeScenarioSelectRow(_ row: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeScenarioRequestPreview")
func OpenRCT2MacNativeScenarioRequestPreview(_ row: Int32)

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

// MARK: - Preview store (classic ParkPreview → RGBA)

@MainActor
@Observable
final class MacScenarioPreviewStore {
    static let shared = MacScenarioPreviewStore()

    var row: Int32 = -1
    var isLoading = false
    var image: NSImage?

    func beginLoading(row: Int32) {
        self.row = row
        isLoading = true
        image = nil
    }

    func clear() {
        row = -1
        isLoading = false
        image = nil
    }

    func apply(row: Int32, rgba: UnsafePointer<UInt8>?, width: Int32, height: Int32) {
        guard self.row == row else { return }
        isLoading = false
        guard let rgba, width > 0, height > 0 else {
            image = nil
            return
        }
        let byteCount = Int(width) * Int(height) * 4
        let data = Data(bytes: rgba, count: byteCount)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  width: Int(width),
                  height: Int(height),
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: Int(width) * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else {
            image = nil
            return
        }
        image = NSImage(cgImage: cgImage, size: NSSize(width: Int(width), height: Int(height)))
    }
}

@_cdecl("OpenRCT2MacNativeScenarioPreviewLoading")
func OpenRCT2MacNativeScenarioPreviewLoading(_ row: Int32) {
    MainActor.assumeIsolated {
        MacScenarioPreviewStore.shared.beginLoading(row: row)
    }
}

@_cdecl("OpenRCT2MacNativeScenarioPreviewReady")
func OpenRCT2MacNativeScenarioPreviewReady(
    _ row: Int32,
    _ rgba: UnsafePointer<UInt8>?,
    _ width: Int32,
    _ height: Int32
) {
    MainActor.assumeIsolated {
        MacScenarioPreviewStore.shared.apply(row: row, rgba: rgba, width: width, height: height)
    }
}

// MARK: - Scenario select (3.20 / title)

enum MacScenarioSelectPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        MacScenarioPreviewStore.shared.clear()
        panel = MacGlassPanelHost.present(
            title: "Select Scenario",
            size: NSSize(width: 760, height: 460),
            minSize: NSSize(width: 560, height: 360),
            root: ScenarioSelectView {
                panel?.close()
                panel = nil
                MacScenarioPreviewStore.shared.clear()
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
    @State private var preview = MacScenarioPreviewStore.shared
    @Bindable private var knobs = MacGlassStyleKnobs.shared

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
            // Title lives in the NSPanel titlebar; Close = traffic lights only.
            if !visibleTabs.isEmpty {
                Picker("", selection: $tab) {
                    ForEach(visibleTabs, id: \.id) { t in
                        Text(t.name).tag(t.id)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .labelsHidden()
                .padding(.horizontal, 10)
                .padding(.top, 18) // tight under titlebar title
                .padding(.bottom, 6)
                .onChange(of: tab) { _, newValue in
                    OpenRCT2MacNativeScenarioSetActiveTab(Int32(newValue))
                    tick &+= 1
                    selectFirstScenario()
                }
            }

            HStack(alignment: .top, spacing: 8) {
                // No List(selection:) — avoids hard system blue; custom rounded highlight only.
                List {
                    ForEach(rows) { row in
                        if row.kind == 0 {
                            Text(row.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(knobs.secondaryLabel)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(knobs.primaryLabel)
                                    .lineLimit(1)
                                if !row.details.isEmpty {
                                    Text(row.details)
                                        .font(.system(size: 10))
                                        .foregroundStyle(knobs.secondaryLabel)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .opacity(row.locked ? 0.55 : 1)
                            .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                MacGlassSelectionBackground(selected: selectedRow == row.index)
                            )
                            .onTapGesture {
                                applyScenarioSelection(row.index)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 28)
                .padding(4)
                .background(MacGlassTextPlate())
                .frame(minWidth: 340)

                detailPane
                    .padding(10)
                    .frame(width: 260, alignment: .topLeading)
                    .background(MacGlassTextPlate())
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .padding(.top, 2)
        }
        .background(Color.clear)
        .onAppear {
            tab = Int(OpenRCT2MacNativeScenarioGetActiveTab())
            tick &+= 1
            selectFirstScenario()
        }
    }

    /// First scenario row (kind == 1) — never leave the list empty/unselected.
    private func selectFirstScenario() {
        guard let first = rows.first(where: { $0.kind == 1 }) else {
            selectedRow = nil
            preview.clear()
            return
        }
        applyScenarioSelection(first.index)
    }

    private func applyScenarioSelection(_ index: Int) {
        selectedRow = index
        let idx = Int32(index)
        if OpenRCT2MacNativeScenarioRowKind(idx) == 1,
           !OpenRCT2MacNativeScenarioRowLocked(idx)
        {
            OpenRCT2MacNativeScenarioRequestPreview(idx)
        } else {
            preview.clear()
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRow, let row = rows.first(where: { $0.index == selectedRow && $0.kind == 1 }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(row.name)
                    .font(.headline)
                    .foregroundStyle(knobs.primaryLabel)

                previewArt

                if !row.details.isEmpty {
                    Text(row.details)
                        .font(.system(size: 11))
                        .foregroundStyle(knobs.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if row.locked {
                    Text("Locked — complete earlier scenarios to unlock.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
                Button("Start Scenario") {
                    if OpenRCT2MacNativeScenarioSelectRow(Int32(row.index)) {
                        onClose()
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .disabled(row.locked)
            }
        } else {
            Text("Choose a scenario")
                .font(.system(size: 12))
                .foregroundStyle(knobs.secondaryLabel)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var previewArt: some View {
        if preview.isLoading {
            ProgressView("Loading preview…")
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let image = preview.image {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .accessibilityLabel("Park preview")
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
        panel = MacGlassPanelHost.present(
            title: "Load Saved Game",
            size: NSSize(width: 560, height: 400),
            minSize: NSSize(width: 420, height: 280),
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
    @Bindable private var knobs = MacGlassStyleKnobs.shared

    private var saveCountLabel: String {
        let count = files.count
        if count == 0 {
            return "No saved games found."
        }
        // Explicit English plural — String inflection markdown was showing raw.
        if count == 1 {
            return "1 save"
        }
        return "\(count) saves"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title in NSPanel titlebar; Close = traffic lights only. Refresh lives in footer.
            Color.clear
                .frame(height: 18)

            // No List(selection:) — avoids hard system blue; custom rounded highlight only.
            List {
                ForEach(files) { file in
                    HStack {
                        Text(file.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(knobs.primaryLabel)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(file.date)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(knobs.secondaryLabel)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        MacGlassSelectionBackground(selected: selected == file.index)
                    )
                    .onTapGesture(count: 2) {
                        selected = file.index
                        if OpenRCT2MacNativeSaveFileLoad(Int32(file.index)) {
                            onClose()
                        }
                    }
                    .onTapGesture(count: 1) {
                        selected = file.index
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 28)
            .padding(4)
            .background(MacGlassTextPlate())
            .padding(.horizontal, 10)

            MacGlassClearFooter {
                MacGlassSecondaryText(text: saveCountLabel)
                Button {
                    OpenRCT2MacNativeSaveFileRefresh()
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Refresh")
                .accessibilityLabel("Refresh")
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

// Compatibility alias used by earlier call sites / docs.
typealias MacGlassBrowserHost = MacGlassPanelHost
