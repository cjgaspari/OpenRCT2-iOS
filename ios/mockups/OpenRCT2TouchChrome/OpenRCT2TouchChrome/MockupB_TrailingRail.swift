import SwiftUI

struct MockupB_TrailingRail: View {
    @Bindable var model: ChromePreviewModel
    @State private var isShowingOverflow = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                HStack(spacing: 12) {
                    GlassIconButton(
                        systemImage: model.isPaused ? "play.fill" : "pause.fill",
                        accessibilityLabel: model.isPaused ? "Resume" : "Pause",
                        action: model.pauseButtonTapped
                    )
                    GlassIconButton(
                        systemImage: model.speed.symbol,
                        accessibilityLabel: "Game speed \(model.speed.rawValue)",
                        action: model.speedButtonTapped
                    )
                }
                Spacer()
                StatusStrip()
            }
            Spacer()
            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    GlassIconButton(
                        systemImage: "square.3.layers.3d.top.filled",
                        accessibilityLabel: "View options",
                        action: { model.toolTapped(.viewOptions) }
                    )
                    GlassIconButton(
                        systemImage: "rotate.right",
                        accessibilityLabel: "Rotate view",
                        action: { model.toolTapped(.viewOptions) }
                    )
                    GlassIconButton(
                        systemImage: "plus",
                        accessibilityLabel: "Build new ride or attraction",
                        prominent: true,
                        controlSize: .large,
                        action: { model.toolTapped(.constructRide) }
                    )
                    GlassIconButton(
                        systemImage: "tree.fill",
                        accessibilityLabel: "Trees",
                        action: { model.toolTapped(.scenery) }
                    )
                    GlassIconButton(
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                        accessibilityLabel: "Paths",
                        action: { model.toolTapped(.footpath) }
                    )
                    GlassIconButton(
                        systemImage: "mountain.2.fill",
                        accessibilityLabel: "Land",
                        action: { model.toolTapped(.land) }
                    )
                    GlassIconButton(
                        systemImage: "drop.fill",
                        accessibilityLabel: "Water",
                        action: { model.toolTapped(.water) }
                    )
                    GlassIconButton(
                        systemImage: "ellipsis",
                        accessibilityLabel: "More tools",
                        action: overflowButtonTapped
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $isShowingOverflow) {
            NavigationStack {
                MenuList(items: ParkMenuCatalog.park + ParkMenuCatalog.view + ParkMenuCatalog.more) { window in
                    isShowingOverflow = false
                    model.toolTapped(window)
                }
                .navigationTitle("More")
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
}
