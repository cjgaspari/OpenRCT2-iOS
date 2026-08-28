import SwiftUI

struct TopChromeHost: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        switch model.top {
        case .united:
            UnitedTopBar(model: model)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .playHUD:
            PlayHUDTopBar(model: model)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .island:
            IslandTopBar(model: model)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Status and pause share one Liquid Glass capsule (two menus, one blob).
struct UnitedTopBar: View {
    @Bindable var model: ChromePreviewModel
    @Namespace private var topUnion

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                StatusMenu(model: model, usesOwnGlass: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect()
                    .glassEffectUnion(id: "topBar", namespace: topUnion)

                PauseSpeedMenu(model: model, usesOwnGlass: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect()
                    .glassEffectUnion(id: "topBar", namespace: topUnion)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Park status and playback")
    }
}

/// One capsule: pause + speed + cash. Camera, speed, and Park/More are in that menu.
struct PlayHUDTopBar: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        Menu {
            PlaybackMenuBody(model: model)
            ParkMoreMenuBody(model: model)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .font(.body.weight(.semibold))
                Text(model.speedLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Divider()
                    .frame(height: 16)
                HStack(spacing: 4) {
                    Image(systemName: "banknote")
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                    TabularStatusValue(text: model.cashText, prototype: "$99,999.99")
                }
                .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .menuOrder(.fixed)
        .menuStyle(.button)
        .buttonBorderShape(.capsule)
        .buttonStyle(.glass)
        .controlSize(.regular)
        .accessibilityLabel(
            "\(model.isPaused ? "Paused" : "Playing"), \(model.speedLabel), cash \(model.cashText)")
        .accessibilityHint("Opens pause, zoom, speed, park, and more")
    }
}

/// Centered island: pause and compact status share one shape.
struct IslandTopBar: View {
    @Bindable var model: ChromePreviewModel
    @Namespace private var islandUnion

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                PauseSpeedMenu(model: model, usesOwnGlass: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect()
                    .glassEffectUnion(id: "island", namespace: islandUnion)

                StatusMenu(model: model, usesOwnGlass: false, showsRatingAndDate: false)
                    .glassEffect()
                    .glassEffectUnion(id: "island", namespace: islandUnion)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Park island")
    }
}
