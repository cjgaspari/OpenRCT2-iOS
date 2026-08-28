import SwiftUI

struct GlassIconButton: View {
    var systemImage: String?
    var title: String?
    let accessibilityLabel: String
    var prominent = false
    var controlSize: ControlSize = .regular
    var action: () -> Void

    var body: some View {
        let button = Button(action: action, label: label)
            .controlSize(controlSize)
            .buttonBorderShape(.circle)
            .accessibilityLabel(accessibilityLabel)

        if prominent {
            button.buttonStyle(.glassProminent).tint(.blue)
        } else {
            button.buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private func label() -> some View {
        if let title {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        } else {
            Image(systemName: systemImage ?? "circle")
                .font(.body.weight(.semibold))
                .imageScale(.medium)
        }
    }
}

struct PauseSpeedMenu: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        Menu {
            Button {
                model.pauseButtonTapped()
            } label: {
                Label(
                    model.isPaused ? "Resume" : "Pause",
                    systemImage: model.isPaused ? "play.fill" : "pause.fill")
            }
            Divider()
            Picker("Speed", selection: $model.speed) {
                ForEach(GameSpeed.allCases, id: \.self) { speed in
                    Text(speed.multiplierLabel).tag(speed)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                Text(model.speed.multiplierLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .menuStyle(.button)
        .menuOrder(.fixed)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .accessibilityLabel(model.isPaused ? "Paused, \(model.speed.multiplierLabel)" : "Playing, \(model.speed.multiplierLabel)")
        .accessibilityHint("Opens pause and game speed")
    }
}

struct CameraCluster: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        HStack(spacing: 12) {
            ControlGroup {
                Button {
                    model.toolTapped(.viewOptions)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.body.weight(.semibold))
                        .imageScale(.medium)
                }
                .accessibilityLabel("Zoom in")

                Button {
                    model.toolTapped(.viewOptions)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.body.weight(.semibold))
                        .imageScale(.medium)
                }
                .accessibilityLabel("Zoom out")
            }
            .controlGroupStyle(.navigation)
            .buttonStyle(.glass)
            .controlSize(.regular)
            .labelStyle(.iconOnly)

            GlassIconButton(
                systemImage: "camera.rotate",
                accessibilityLabel: "Rotate view",
                action: { model.toolTapped(.viewOptions) }
            )
        }
    }
}

struct StatusStrip: View {
    var body: some View {
        HStack(spacing: 14) {
            labeled("banknote", "$12,480")
            labeled("person.3.fill", "248")
            labeled("star.fill", "693")
            labeled("calendar", "Mar 14")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
