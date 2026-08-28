/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

struct ParkChromeRootView: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        VStack {
            TopChromeBar(model: model)
            Spacer()
            HStack(alignment: .bottom) {
                if model.swapBottomControls {
                    BuildCluster(model: model)
                    Spacer()
                    ParkChromeDockView(model: model)
                } else {
                    ParkChromeDockView(model: model)
                    Spacer()
                    BuildCluster(model: model)
                }
            }
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .opacity(model.isParkOpen ? 1 : 0)
        .allowsHitTesting(model.isParkOpen)
    }
}

struct ParkChromeDockView: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        ViewRotateCluster(model: model)
            .sheet(isPresented: $model.isShowingViewTools) {
                ViewToolsSheet(model: model)
            }
    }
}

struct BuildToolsSheet: View {
    @ObservedObject var model: ParkChromeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ChromeToolsSheetScaffold(title: "Build", onClose: dismissSheet) {
            List {
                ParkToolsButtonSection(title: nil, items: ParkMenuCatalog.build, onSelect: select)
            }
            .listStyle(.plain)
            .modifier(ClearListBackground())
        }
    }

    private func select(_ item: ParkMenuItem) {
        dismissSheet()
        model.queue(item.action)
    }

    private func dismissSheet() {
        model.isShowingBuildTools = false
        dismiss()
    }
}

struct ViewToolsSheet: View {
    @ObservedObject var model: ParkChromeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ChromeToolsSheetScaffold(title: "View", onClose: dismissSheet) {
            List {
                ParkToolsButtonSection(title: "Windows", items: ParkMenuCatalog.viewWindows, onSelect: select)

                Section("Options") {
                    Toggle(isOn: $model.swapBottomControls) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Swap bottom controls")
                                    .font(.body.weight(.semibold))
                                Text("View and Build trade edges")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            ParkChromeSymbol(
                                systemImage: "arrow.left.arrow.right",
                                primary: .blue,
                                secondary: .cyan)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("openrct2.touch.swapBottomControls")

                    ForEach(ParkMenuCatalog.viewToggles) { item in
                        Toggle(isOn: model.toggleBinding(for: item.action)) {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .modifier(ClearListBackground())
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Zoom in", systemImage: "plus.magnifyingglass") {
                        model.queue(.zoomIn)
                    }
                    .labelStyle(.iconOnly)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.green, .mint)
                    .accessibilityIdentifier("openrct2.touch.zoomIn")

                    Button("Zoom out", systemImage: "minus.magnifyingglass") {
                        model.queue(.zoomOut)
                    }
                    .labelStyle(.iconOnly)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.orange, .yellow)
                    .accessibilityIdentifier("openrct2.touch.zoomOut")
                }
            }
        }
    }

    private func select(_ item: ParkMenuItem) {
        dismissSheet()
        model.queue(item.action)
    }

    private func dismissSheet() {
        model.isShowingViewTools = false
        dismiss()
    }
}

private struct ChromeToolsSheetScaffold<Content: View>: View {
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationSizing(.page)
    }
}

private struct ParkToolsButtonSection: View {
    var title: String?
    let items: [ParkMenuItem]
    let onSelect: (ParkMenuItem) -> Void

    var body: some View {
        if let title {
            Section(title) {
                rows
            }
        } else {
            Section {
                rows
            }
        }
    }

    private var rows: some View {
        ForEach(items) { item in
            Button {
                onSelect(item)
            } label: {
                MenuRow(item: item)
            }
            .listRowBackground(Color.clear)
        }
    }
}

private struct ClearListBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
    }
}
