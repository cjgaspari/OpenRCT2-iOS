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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Messages")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MacGlassPanelStyle.primaryLabel)
                Spacer()
                Button("Refresh") {
                    OpenRCT2MacNativeNewsRefresh()
                    reload()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                Button("Close", action: onClose)
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(selection: $selected) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.date)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MacGlassPanelStyle.secondaryLabel)
                        Text(item.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MacGlassPanelStyle.primaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .tag(item.index)
                    .listRowBackground(
                        selected == item.index
                            ? Color.accentColor.opacity(0.28)
                            : Color.clear
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(MacGlassPanelStyle.textPlate())
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Text(items.isEmpty ? "No messages yet." : "\(items.count) message(s)")
                    .font(.system(size: 10))
                    .foregroundStyle(MacGlassPanelStyle.secondaryLabel)
                Spacer()
                if let selected, let item = items.first(where: { $0.index == selected }) {
                    if item.hasSubject {
                        Button("Open") {
                            OpenRCT2MacNativeNewsOpenSubject(Int32(item.index))
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                    if item.hasLocation {
                        Button("Locate") {
                            OpenRCT2MacNativeNewsLocate(Int32(item.index))
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            }
            .padding(12)
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
                    text: String(cString: text),
                    hasSubject: OpenRCT2MacNativeNewsHasSubject(Int32(i)),
                    hasLocation: OpenRCT2MacNativeNewsHasLocation(Int32(i))
                )
            )
        }
        items = next
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
