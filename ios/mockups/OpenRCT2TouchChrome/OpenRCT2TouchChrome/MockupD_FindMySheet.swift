import SwiftUI

struct MockupD_FindMySheet: View {
    @Bindable var model: ChromePreviewModel
    @State private var isSheetPresented = true

    var body: some View {
        HStack {
            Spacer()
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    GlassIconButton(
                        systemImage: "square.3.layers.3d.top.filled",
                        accessibilityLabel: "View options",
                        action: { model.toolTapped(.viewOptions) }
                    )
                    GlassIconButton(
                        systemImage: "location.fill",
                        accessibilityLabel: "Center park",
                        action: { model.toolTapped(.map) }
                    )
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .sheet(isPresented: $isSheetPresented) {
            sheetContent
                .presentationDetents(
                    [.height(ChromePreviewModel.compactSheetHeight), .medium, .large],
                    selection: $model.sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(ChromePreviewModel.compactSheetHeight)))
                .interactiveDismissDisabled()
                .presentationContentInteraction(.scrolls)
        }
        .onAppear(perform: presentSheetIfNeeded)
    }

    /// System sheets already use Liquid Glass. TabView is not used here because its
    /// content fill is opaque on iOS and `containerBackground(..., for: .tabView)` is watchOS-only.
    private var sheetContent: some View {
        NavigationStack {
            tabBody
                .scrollContentBackground(.hidden)
                .containerBackground(.clear, for: .navigation)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .navigationTitle(model.sheetTab.title)
                .toolbar {
                    if model.sheetTab == .build {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: buildRideButtonTapped) {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Build new ride or attraction")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 12) {
                            Button(action: model.pauseButtonTapped) {
                                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                            }
                            .accessibilityLabel(model.isPaused ? "Resume" : "Pause")
                            Button(action: model.speedButtonTapped) {
                                Image(systemName: model.speed.symbol)
                            }
                            .accessibilityLabel("Game speed \(model.speed.rawValue)")
                        }
                    }
                }
                .safeAreaBar(edge: .bottom) {
                    sheetTabBar
                }
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch model.sheetTab {
        case .build:
            sheetList(items: ParkMenuCatalog.build)
        case .park:
            sheetList(items: ParkMenuCatalog.park)
        case .view:
            viewList
        case .more:
            sheetList(items: ParkMenuCatalog.more)
        }
    }

    private func sheetList(items: [ParkMenuItem]) -> some View {
        List {
            ForEach(items) { item in
                Button {
                    model.toolTapped(item.window)
                } label: {
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
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    private var viewList: some View {
        List {
            Section("Camera") {
                ForEach(ParkMenuCatalog.view) { item in
                    Button {
                        model.toolTapped(item.window)
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            Section("See-through") {
                ForEach(ParkMenuCatalog.viewToggles, id: \.self) { name in
                    Toggle(name, isOn: $model[viewFlag: name])
                        .listRowBackground(Color.clear)
                }
            }
        }
    }

    private var sheetTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SheetTab.allCases) { tab in
                Button {
                    model.sheetTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.body.weight(.semibold))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.sheetTab == tab ? Color.accentColor : Color.primary.opacity(0.7))
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(model.sheetTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sheet tabs")
    }

    private func buildRideButtonTapped() {
        model.toolTapped(.constructRide)
    }

    private func presentSheetIfNeeded() {
        isSheetPresented = true
    }
}
