/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Tier 3.1 recentNews — mid-legibility clear Liquid Glass dense list.
 *****************************************************************************/

import AppKit
import SwiftUI

@_silgen_name("OpenRCT2MacNativeNewsCount")
func OpenRCT2MacNativeNewsCount() -> Int32
@_silgen_name("OpenRCT2MacNativeNewsGetDate")
func OpenRCT2MacNativeNewsGetDate(_ index: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeNewsGetText")
func OpenRCT2MacNativeNewsGetText(_ index: Int32, _ out: UnsafeMutablePointer<CChar>, _ outLen: Int)
@_silgen_name("OpenRCT2MacNativeNewsHasSubject")
func OpenRCT2MacNativeNewsHasSubject(_ index: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeNewsHasLocation")
func OpenRCT2MacNativeNewsHasLocation(_ index: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeNewsOpenSubject")
func OpenRCT2MacNativeNewsOpenSubject(_ index: Int32)
@_silgen_name("OpenRCT2MacNativeNewsLocate")
func OpenRCT2MacNativeNewsLocate(_ index: Int32)
@_silgen_name("OpenRCT2MacNativeNewsRefresh")
func OpenRCT2MacNativeNewsRefresh()

enum MacRecentNewsPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        OpenRCT2MacNativeNewsRefresh()
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacGlassPanelHost.present(
            title: "Recent Messages",
            size: NSSize(width: 440, height: 380),
            minSize: NSSize(width: 360, height: 260),
            root: RecentNewsView {
                panel?.close()
                panel = nil
            }
        )
        return true
    }
}

private struct RecentNewsView: View {
    let onClose: () -> Void
    @State private var selected: Int?
    @State private var items: [NewsRow] = []
    @Bindable private var knobs = MacGlassStyleKnobs.shared

    private var messageCountLabel: String {
        let count = items.count
        if count == 0 { return "No messages" }
        if count == 1 { return "1 message" }
        return "\(count) messages"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title in NSPanel titlebar; Close = traffic lights only.
            Color.clear
                .frame(height: 18)

            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.date)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(knobs.secondaryLabel)
                        Text(item.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(knobs.primaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        MacGlassSelectionBackground(selected: selected == item.index)
                    )
                    .onTapGesture {
                        selected = item.index
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
                MacGlassSecondaryText(text: messageCountLabel)
                Button {
                    OpenRCT2MacNativeNewsRefresh()
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Refresh")
                .accessibilityLabel("Refresh")
                Spacer()
                if let selected, let item = items.first(where: { $0.index == selected }) {
                    if item.hasSubject {
                        Button {
                            OpenRCT2MacNativeNewsOpenSubject(Int32(item.index))
                        } label: {
                            Label("Open", systemImage: "info.circle")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                    if item.hasLocation {
                        Button {
                            OpenRCT2MacNativeNewsLocate(Int32(item.index))
                        } label: {
                            Label("Locate", systemImage: "location.viewfinder")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear { reload() }
    }

    private func reload() {
        let count = Int(OpenRCT2MacNativeNewsCount())
        var next: [NewsRow] = []
        for i in 0..<count {
            var date = [CChar](repeating: 0, count: 128)
            var text = [CChar](repeating: 0, count: 1024)
            OpenRCT2MacNativeNewsGetDate(Int32(i), &date, date.count)
            OpenRCT2MacNativeNewsGetText(Int32(i), &text, text.count)
            next.append(
                NewsRow(
                    index: i,
                    date: String(cString: date),
                    text: Self.cleanNewsText(String(cString: text)),
                    hasSubject: OpenRCT2MacNativeNewsHasSubject(Int32(i)),
                    hasLocation: OpenRCT2MacNativeNewsHasLocation(Int32(i))
                )
            )
        }
        items = next
        if selected == nil, let first = items.first {
            selected = first.index
        } else if let selected, !items.contains(where: { $0.index == selected }) {
            self.selected = items.first?.index
        }
    }

    /// Format leftovers like `{NEWLINE}` / literal "NEWLINE".
    private static func cleanNewsText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "NEWLINE", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct NewsRow: Identifiable {
    var id: Int { index }
    let index: Int
    let date: String
    let text: String
    let hasSubject: Bool
    let hasLocation: Bool
}

@_cdecl("OpenRCT2MacNativeRecentNewsShow")
func OpenRCT2MacNativeRecentNewsShow() -> Bool {
    MainActor.assumeIsolated { MacRecentNewsPanel.show() }
}
