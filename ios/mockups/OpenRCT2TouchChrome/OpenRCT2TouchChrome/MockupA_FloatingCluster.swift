import SwiftUI

struct MockupA_FloatingCluster: View {
    @Bindable var model: ChromePreviewModel
    @State private var isShowingOverflow = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                CameraCluster(model: model)
            }
            .padding(.horizontal, 16)
            Spacer()
            StatusStrip()
                .padding(.bottom, 8)
            GlassEffectContainer(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    GlassIconButton(
                        systemImage: "tree.fill",
                        accessibilityLabel: "Trees",
                        action: { model.toolTapped(.scenery) }
                    )
                    GlassIconButton(
                        systemImage: "plus",
                        accessibilityLabel: "Build new ride or attraction",
                        prominent: true,
                        size: 56,
                        action: { model.toolTapped(.constructRide) }
                    )
                    GlassIconButton(
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                        accessibilityLabel: "Paths",
                        action: { model.toolTapped(.footpath) }
                    )
                    GlassIconButton(
                        systemImage: "ellipsis",
                        accessibilityLabel: "More tools",
                        action: overflowButtonTapped
                    )
                }
            }
        }
        .padding(.bottom, 8)
        .safeAreaPadding(.horizontal, 16)
        .sheet(isPresented: $isShowingOverflow) {
            NavigationStack {
                List {
                    Section("Build") {
                        ForEach(Array(ParkMenuCatalog.build.dropFirst(3))) { item in
                            Button {
                                isShowingOverflow = false
                                model.toolTapped(item.window)
                            } label: {
                                menuLabel(item)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    Section("Park") {
                        ForEach(ParkMenuCatalog.park) { item in
                            Button {
                                isShowingOverflow = false
                                model.toolTapped(item.window)
                            } label: {
                                menuLabel(item)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    Section("View") {
                        ForEach(ParkMenuCatalog.view) { item in
                            Button {
                                isShowingOverflow = false
                                model.toolTapped(item.window)
                            } label: {
                                menuLabel(item)
                            }
                            .listRowBackground(Color.clear)
                        }
                        ForEach(ParkMenuCatalog.viewToggles, id: \.self) { name in
                            Toggle(name, isOn: $model[viewFlag: name])
                                .listRowBackground(Color.clear)
                        }
                    }
                    Section("More") {
                        ForEach(ParkMenuCatalog.more) { item in
                            Button {
                                isShowingOverflow = false
                                model.toolTapped(item.window)
                            } label: {
                                menuLabel(item)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle("Park tools")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isShowingOverflow = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func overflowButtonTapped() {
        isShowingOverflow = true
    }

    private func menuLabel(_ item: ParkMenuItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: item.systemImage)
        }
    }
}
