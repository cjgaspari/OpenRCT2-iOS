/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

/// Icon-only glass control. The glass button style supplies the circle; the
/// label is only the glyph so the material does not pick up an extra 48pt frame.
/// Hit area stays at least 44pt via `controlSize` (HIG minimum).
struct GlassIconButton: View {
    var systemImage: String?
    var title: String?
    var fallbackImage: String?
    let accessibilityLabel: String
    var accessibilityIdentifier: String?
    var prominent = false
    var controlSize: ControlSize = .regular
    var action: () -> Void

    var body: some View {
        Button(action: action, label: label)
            .controlSize(controlSize)
            .modifier(CircleButtonBorder())
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
            .modifier(GlassButtonChrome(prominent: prominent))
    }

    private func label() -> some View {
        Group {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            } else {
                Image(systemName: resolvedSymbol)
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
            }
        }
        .contentShape(Circle())
    }

    private var resolvedSymbol: String {
        systemImage ?? fallbackImage ?? "circle"
    }
}

struct ChromeGlassCluster<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

/// Tap-to-open `Menu` (not a long-press `contextMenu`). Label shows play/pause
/// plus the current speed, matching a compact pull-down control.
struct PauseSpeedMenu: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        Menu {
            Button {
                model.queue(.pause)
            } label: {
                Label(
                    model.isPaused ? "Resume" : "Pause",
                    systemImage: model.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityIdentifier("openrct2.touch.pause")

            Divider()

            Picker("Speed", selection: speedBinding) {
                Text("1x").tag(UInt8(1))
                Text("2x").tag(UInt8(2))
                Text("3x").tag(UInt8(3))
                Text("4x").tag(UInt8(4))
            }
            .accessibilityIdentifier("openrct2.touch.speed")
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
        .modifier(PlaybackMenuChrome())
        .controlSize(.regular)
        .accessibilityLabel(menuAccessibilityLabel)
        .accessibilityHint("Opens pause and game speed")
        .accessibilityIdentifier("openrct2.touch.playbackMenu")
    }

    private var speedBinding: Binding<UInt8> {
        Binding(
            get: { max(1, min(4, model.speed)) },
            set: { model.queue(.gameSpeed, extra: Int32($0)) }
        )
    }

    private var menuAccessibilityLabel: String {
        let motion = model.isPaused ? "Paused" : "Playing"
        return "\(motion), \(model.speedLabel)"
    }
}

/// Zoom in/out as one clustered control; rotate stays a separate capsule.
struct CameraCluster: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        HStack(spacing: 12) {
            ZoomPair(model: model)
            GlassIconButton(
                systemImage: ParkMenuCatalog.rotateViewSymbol,
                fallbackImage: ParkMenuCatalog.rotateViewFallbackSymbol,
                accessibilityLabel: "Rotate view",
                accessibilityIdentifier: "openrct2.touch.rotate",
                action: { model.queue(.rotateCW) }
            )
        }
        .fixedSize()
        .accessibilityIdentifier("openrct2.touch.cameraCluster")
    }
}

private struct ZoomPair: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        ControlGroup {
            Button {
                model.queue(.zoomIn)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
            }
            .accessibilityLabel("Zoom in")
            .accessibilityIdentifier("openrct2.touch.zoomIn")

            Button {
                model.queue(.zoomOut)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
            }
            .accessibilityLabel("Zoom out")
            .accessibilityIdentifier("openrct2.touch.zoomOut")
        }
        .controlGroupStyle(.navigation)
        .controlSize(.regular)
        .labelStyle(.iconOnly)
        .modifier(GlassControlGroupChrome())
    }
}

struct StatusStrip: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        HStack(spacing: 14) {
            labeled("banknote", model.cash)
            labeled("person.3.fill", model.guests)
            labeled("star.fill", model.rating)
            labeled("calendar", model.date)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .modifier(ChromeCapsuleBackground())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Cash \(model.cash), \(model.guests) guests, park rating \(model.rating), \(model.date)")
        .accessibilityIdentifier("openrct2.touch.statusStrip")
    }

    private func labeled(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
    }
}

private struct CircleButtonBorder: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.buttonBorderShape(.circle)
        } else {
            content
        }
    }
}

private struct GlassButtonChrome: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent).tint(.blue)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            content
                .buttonStyle(.plain)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(minWidth: 44, minHeight: 44)
                .background(prominent ? Color.blue : Color.primary.opacity(0.12), in: Circle())
        }
    }
}

private struct PlaybackMenuChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .menuOrder(.fixed)
                .menuStyle(.button)
                .buttonBorderShape(.capsule)
                .buttonStyle(.glass)
        } else if #available(iOS 16.4, *) {
            content
                .menuOrder(.fixed)
                .menuStyle(.button)
                .buttonBorderShape(.capsule)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: Capsule())
        } else if #available(iOS 16.0, *) {
            content
                .menuStyle(.button)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: Capsule())
        } else {
            content
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color.primary.opacity(0.12), in: Capsule())
        }
    }
}

private struct GlassControlGroupChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            ChromeGlassCluster(spacing: 0) {
                content.buttonStyle(.glass)
            }
        } else {
            content
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .padding(.horizontal, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct ChromeCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
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
