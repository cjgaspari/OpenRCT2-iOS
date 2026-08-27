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
                MenuList(items: Array(ParkMenuCatalog.build.dropFirst(3)) + ParkMenuCatalog.park + ParkMenuCatalog.view + ParkMenuCatalog.more) { window in
                    isShowingOverflow = false
                    model.toolTapped(window)
                }
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
}
