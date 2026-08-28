import SwiftUI

struct BottomChromeHost: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        Group {
            if model.bottom == .toolbar {
                BottomToolbarBar(model: model)
            } else if model.leftHandedControls {
                HStack(alignment: .bottom, spacing: 12) {
                    trailingCluster
                    Spacer(minLength: 12)
                    leadingCluster
                }
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    leadingCluster
                    Spacer(minLength: 12)
                    trailingCluster
                }
            }
        }
        .sheet(isPresented: $model.isShowingParkTools) {
            ParkToolsSheet(model: model)
        }
    }

    @ViewBuilder
    private var leadingCluster: some View {
        switch model.bottom {
        case .split:
            BuildDockCluster(model: model)
        case .toolbar:
            EmptyView()
        case .labeled:
            LabeledBuildDock(model: model)
        }
    }

    @ViewBuilder
    private var trailingCluster: some View {
        switch model.bottom {
        case .split:
            ToolsRotateCluster(model: model, axis: .horizontal)
        case .toolbar:
            EmptyView()
        case .labeled:
            ToolsRotateCluster(model: model, axis: .vertical)
        }
    }
}

struct BuildDockCluster: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                GlassIconButton(
                    systemImage: "tree.fill",
                    accessibilityLabel: "Trees",
                    action: { model.toolTapped(.scenery) }
                )
                GlassIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Build new ride or attraction",
                    prominent: true,
                    action: { model.toolTapped(.constructRide) }
                )
                GlassIconButton(
                    systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                    accessibilityLabel: "Paths",
                    action: { model.toolTapped(.footpath) }
                )
            }
        }
        .fixedSize()
    }
}

enum ClusterAxis {
    case horizontal
    case vertical
}

struct ToolsRotateCluster: View {
    @Bindable var model: ChromePreviewModel
    var axis: ClusterAxis
    @Namespace private var unionNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            switch axis {
            case .horizontal:
                HStack(spacing: 8) {
                    icons
                }
            case .vertical:
                VStack(spacing: 8) {
                    icons
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private var icons: some View {
        UnionedGlassIcon(
            systemImage: ParkMenuCatalog.toolsSheetSymbol,
            accessibilityLabel: "Build and view tools",
            unionID: "overflowRotate",
            namespace: unionNamespace
        ) {
            model.isShowingParkTools = true
        }
        UnionedGlassIcon(
            systemImage: ParkMenuCatalog.rotateViewSymbol,
            accessibilityLabel: "Rotate view",
            unionID: "overflowRotate",
            namespace: unionNamespace
        ) {
            model.rotateButtonTapped()
        }
    }
}

/// One spanning capsule. Build trio and tools/rotate sit in the same bar.
struct BottomToolbarBar: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        HStack(spacing: 4) {
            if model.leftHandedControls {
                thumbPair
                Spacer(minLength: 8)
                buildTrio
            } else {
                buildTrio
                Spacer(minLength: 8)
                thumbPair
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity)
    }

    private var buildTrio: some View {
        HStack(spacing: 4) {
            toolbarIcon("tree.fill", "Trees") {
                model.toolTapped(.scenery)
            }
            toolbarIcon("plus", "Build new ride or attraction", tint: .blue) {
                model.toolTapped(.constructRide)
            }
            toolbarIcon(
                "point.bottomleft.forward.to.point.topright.scurvepath",
                "Paths"
            ) {
                model.toolTapped(.footpath)
            }
        }
    }

    private var thumbPair: some View {
        HStack(spacing: 4) {
            toolbarIcon(ParkMenuCatalog.toolsSheetSymbol, "Build and view tools") {
                model.isShowingParkTools = true
            }
            toolbarIcon(ParkMenuCatalog.rotateViewSymbol, "Rotate view") {
                model.rotateButtonTapped()
            }
        }
    }

    private func toolbarIcon(
        _ systemImage: String,
        _ label: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .imageScale(.medium)
                .foregroundStyle(tint ?? .primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct LabeledBuildDock: View {
    @Bindable var model: ChromePreviewModel
    @Namespace private var labeledUnion

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                labeledIcon("tree.fill", "Trees") {
                    model.toolTapped(.scenery)
                }
                labeledIcon("car.fill", "Build") {
                    model.toolTapped(.constructRide)
                }
                labeledIcon(
                    "point.bottomleft.forward.to.point.topright.scurvepath",
                    "Paths"
                ) {
                    model.toolTapped(.footpath)
                }
            }
        }
    }

    private func labeledIcon(
        _ systemImage: String,
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                    .frame(height: 20)
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(width: 56, height: 52)
            .contentShape(Rectangle())
            .glassEffect()
            .glassEffectUnion(id: "labeledBuild", namespace: labeledUnion)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "Build" ? "Build new ride or attraction" : title)
    }
}
