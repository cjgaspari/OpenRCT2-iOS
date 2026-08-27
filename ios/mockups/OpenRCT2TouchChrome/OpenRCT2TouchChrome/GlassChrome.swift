import SwiftUI

struct GlassIconButton: View {
    var systemImage: String?
    var title: String?
    let accessibilityLabel: String
    var prominent = false
    var size: CGFloat = 48
    var action: () -> Void

    var body: some View {
        if prominent {
            Button(action: action, label: label)
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action, label: label)
                .buttonStyle(.glass)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    @ViewBuilder
    private func label() -> some View {
        if let title {
            Text(title)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemImage ?? "circle")
                .font(.body.weight(.semibold))
                .frame(width: size, height: size)
        }
    }
}

struct CameraCluster: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                GlassIconButton(
                    systemImage: model.isPaused ? "play.fill" : "pause.fill",
                    accessibilityLabel: model.isPaused ? "Resume" : "Pause",
                    action: model.pauseButtonTapped
                )
                GlassIconButton(
                    title: model.speed.multiplierLabel,
                    accessibilityLabel: "Game speed \(model.speed.multiplierLabel)",
                    action: model.speedButtonTapped
                )
                GlassIconButton(
                    systemImage: "plus.magnifyingglass",
                    accessibilityLabel: "Zoom in",
                    action: { model.toolTapped(.viewOptions) }
                )
                GlassIconButton(
                    systemImage: "minus.magnifyingglass",
                    accessibilityLabel: "Zoom out",
                    action: { model.toolTapped(.viewOptions) }
                )
                GlassIconButton(
                    systemImage: "camera.rotate",
                    accessibilityLabel: "Rotate view",
                    action: { model.toolTapped(.viewOptions) }
                )
            }
        }
    }
}

struct StatusStrip: View {
    var body: some View {
        HStack(spacing: 16) {
            labeled("banknote", "$12,480")
            labeled("person.3.fill", "248")
            labeled("star.fill", "693")
            labeled("calendar", "Mar 14")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cash $12,480, 248 guests, park rating 693, 14 March")
    }

    private func labeled(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
    }
}

struct MenuList: View {
    let items: [ParkMenuItem]
    var onSelect: (ParkWindow) -> Void

    var body: some View {
        List(items) { item in
            Button {
                onSelect(item.window)
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
        }
        .listStyle(.plain)
    }
}
