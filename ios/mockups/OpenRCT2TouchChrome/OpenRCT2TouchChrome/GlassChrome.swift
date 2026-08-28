import SwiftUI

/// Icon-only glass control matching the live overlay: `.glass` only, optional blue tint.
struct GlassIconButton: View {
    var systemImage: String
    let accessibilityLabel: String
    var prominent = false
    var controlSize: ControlSize = .regular
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .imageScale(.medium)
        }
        .controlSize(controlSize)
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .modifier(ProminentTint(enabled: prominent))
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ProminentTint: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.tint(.blue)
        } else {
            content
        }
    }
}

struct UnionedGlassIcon: View {
    let systemImage: String
    let accessibilityLabel: String
    let unionID: String
    let namespace: Namespace.ID
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .imageScale(.medium)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .glassEffect()
                .glassEffectUnion(id: unionID, namespace: namespace)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct TabularStatusValue: View {
    let text: String
    let prototype: String

    var body: some View {
        Text(prototype)
            .hidden()
            .overlay(alignment: .leading) {
                Text(text)
                    .contentTransition(.numericText())
            }
            .monospacedDigit()
            .lineLimit(1)
            .animation(.default, value: text)
    }
}

struct StatusMetrics: View {
    let values: ParkStatusValues
    var showsRatingAndDate = true

    var body: some View {
        HStack(spacing: 10) {
            statusItem("banknote", values.cash, prototype: "$99,999.99", color: .green)
            statusItem("person.3.fill", values.guests, prototype: "9999", color: .purple)
            if showsRatingAndDate {
                statusItem("star.fill", values.rating, prototype: "999", color: .yellow)
                calendarItem(values.date)
            }
        }
        .font(.caption.weight(.semibold))
    }

    private func statusItem(_ symbol: String, _ text: String, prototype: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            TabularStatusValue(text: text, prototype: prototype)
        }
    }

    private func calendarItem(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red, .white)
            TabularStatusValue(text: text, prototype: "May 31")
        }
    }
}

struct PlaybackMenuBody: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        Button {
            model.pauseButtonTapped()
        } label: {
            Label(
                model.isPaused ? "Resume" : "Pause",
                systemImage: model.isPaused ? "play.fill" : "pause.fill")
        }

        Section("Camera") {
            Button {
                model.zoomInButtonTapped()
            } label: {
                Label("Zoom in", systemImage: "plus.magnifyingglass")
            }
            Button {
                model.zoomOutButtonTapped()
            } label: {
                Label("Zoom out", systemImage: "minus.magnifyingglass")
            }
        }

        Section("Speed") {
            Picker("Speed", selection: $model.speed) {
                ForEach(GameSpeed.allCases, id: \.self) { speed in
                    Text(speed.multiplierLabel).tag(speed)
                }
            }
        }
    }
}

struct ParkMoreMenuBody: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        Section("Park") {
            ForEach(ParkMenuCatalog.park) { item in
                Button {
                    model.toolTapped(item.window)
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        }
        Section("More") {
            ForEach(ParkMenuCatalog.fileAndSettings) { item in
                Button {
                    model.toolTapped(item.window)
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        }
        Section {
            Button(role: .destructive) {
                model.toolTapped(.quitToMenu)
            } label: {
                Label("Quit to menu", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        Section {
            Toggle("Left-handed controls", isOn: $model.leftHandedControls)
        }
    }
}

struct PauseSpeedMenu: View {
    @Bindable var model: ChromePreviewModel
    var usesOwnGlass = true

    var body: some View {
        Menu {
            PlaybackMenuBody(model: model)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                Text(model.speedLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .menuOrder(.fixed)
        .menuStyle(.button)
        .modifier(OptionalGlassCapsule(enabled: usesOwnGlass))
        .controlSize(.regular)
        .accessibilityLabel(
            model.isPaused
                ? "Paused, \(model.speedLabel)"
                : "Playing, \(model.speedLabel)")
        .accessibilityHint("Opens pause, zoom, and game speed")
    }
}

struct StatusMenu: View {
    @Bindable var model: ChromePreviewModel
    var usesOwnGlass = true
    var showsRatingAndDate = true

    var body: some View {
        Menu {
            ParkMoreMenuBody(model: model)
        } label: {
            StatusMetrics(values: model.statusValues, showsRatingAndDate: showsRatingAndDate)
                .padding(.horizontal, usesOwnGlass ? 12 : 4)
                .padding(.vertical, usesOwnGlass ? 7 : 4)
        }
        .menuOrder(.fixed)
        .menuStyle(.button)
        .modifier(OptionalGlassCapsule(enabled: usesOwnGlass))
        .controlSize(.regular)
        .accessibilityLabel(
            "Cash \(model.cashText), \(model.guestsText) guests, park rating \(model.ratingText), \(model.date)")
        .accessibilityHint("Opens park information and more")
    }
}

private struct OptionalGlassCapsule: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .buttonBorderShape(.capsule)
                .buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

struct MenuRow: View {
    let item: ParkMenuItem

    var body: some View {
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
