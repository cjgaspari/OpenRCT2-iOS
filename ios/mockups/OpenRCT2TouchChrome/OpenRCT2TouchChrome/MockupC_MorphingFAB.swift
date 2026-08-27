import SwiftUI

struct MockupC_MorphingFAB: View {
    @Bindable var model: ChromePreviewModel
    @Namespace private var fabNamespace
    @State private var isShowingOverflow = false

    private let fabTools: [(id: String, image: String, label: String, window: ParkWindow)] = [
        ("land", "mountain.2.fill", "Land", .land),
        ("water", "drop.fill", "Water", .water),
        ("trees", "tree.fill", "Trees", .scenery),
        ("paths", "point.bottomleft.forward.to.point.topright.scurvepath", "Paths", .footpath),
        ("rides", "tram.fill", "Ride list", .rideList),
    ]

    var body: some View {
        VStack {
            HStack {
                CameraCluster(model: model)
                Spacer()
                GlassIconButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "More tools",
                    action: overflowButtonTapped
                )
            }
            Spacer()
            HStack(alignment: .bottom) {
                StatusStrip()
                Spacer()
                GlassEffectContainer(spacing: 40) {
                    VStack(spacing: 16) {
                        if model.isFABExpanded {
                            ForEach(fabTools, id: \.id) { tool in
                                GlassIconButton(
                                    systemImage: tool.image,
                                    accessibilityLabel: tool.label,
                                    action: { model.toolTapped(tool.window) }
                                )
                                .glassEffectID(tool.id, in: fabNamespace)
                            }
                        }
                        Button(action: fabButtonTapped) {
                            Image(systemName: model.isFABExpanded ? "xmark" : "plus")
                                .font(.title2.weight(.semibold))
                                .frame(width: 56, height: 56)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                        .glassEffectID("fab", in: fabNamespace)
                        .accessibilityLabel(model.isFABExpanded ? "Close build tools" : "Build")
                    }
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

    private func fabButtonTapped() {
        withAnimation(.spring(duration: 0.35)) {
            model.fabButtonTapped()
        }
    }

    private func overflowButtonTapped() {
        isShowingOverflow = true
    }
}
