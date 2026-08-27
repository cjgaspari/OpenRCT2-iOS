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
            HStack {
                Spacer()
                CameraCluster(model: model)
            }
            Spacer()
            ParkChromeDockView(model: model)
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
        VStack(spacing: 8) {
            StatusStrip(model: model)
            ChromeGlassCluster(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    GlassIconButton(
                        systemImage: "tree.fill",
                        fallbackImage: "leaf.fill",
                        accessibilityLabel: "Trees",
                        accessibilityIdentifier: "openrct2.touch.trees",
                        action: { model.queue(.scenery) }
                    )
                    GlassIconButton(
                        systemImage: "plus",
                        fallbackImage: "plus.circle.fill",
                        accessibilityLabel: "Build new ride or attraction",
                        accessibilityIdentifier: "openrct2.touch.buildRide",
                        prominent: true,
                        size: 56,
                        action: { model.queue(.constructRide) }
                    )
                    GlassIconButton(
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                        fallbackImage: "road.lanes",
                        accessibilityLabel: "Paths",
                        accessibilityIdentifier: "openrct2.touch.paths",
                        action: { model.queue(.footpath) }
                    )
                    GlassIconButton(
                        systemImage: "ellipsis",
                        fallbackImage: "ellipsis.circle",
                        accessibilityLabel: "More tools",
                        accessibilityIdentifier: "openrct2.touch.more",
                        action: { model.isShowingParkTools = true }
                    )
                }
            }
            .accessibilityIdentifier("openrct2.touch.nativeChrome")
        }
        .fixedSize()
        .sheet(isPresented: $model.isShowingParkTools) {
            ParkToolsSheet(model: model)
        }
    }
}

struct ParkToolsSheet: View {
    @ObservedObject var model: ParkChromeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        sheetNavigation {
            List {
                Section("Build") {
                    ForEach(ParkMenuCatalog.overflowBuild) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section("Park") {
                    ForEach(ParkMenuCatalog.park) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section("View") {
                    ForEach(ParkMenuCatalog.view) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                    ForEach(ParkMenuCatalog.viewToggles) { item in
                        Toggle(isOn: model.toggleBinding(for: item.action)) {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section("More") {
                    ForEach(ParkMenuCatalog.more) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .modifier(ClearListBackground())
        }
    }

    @ViewBuilder
    private func sheetNavigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
                    .navigationTitle("Park tools")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismissSheet() }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .modifier(FullWidthSheetSizing())
        } else {
            NavigationView {
                content()
                    .navigationTitle("Park tools")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismissSheet() }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    private func select(_ item: ParkMenuItem) {
        dismissSheet()
        model.queue(item.action)
    }

    private func dismissSheet() {
        model.isShowingParkTools = false
        dismiss()
    }
}

private struct FullWidthSheetSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}

private struct ClearListBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}
