/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

struct GlassIconButton: View {
    var systemImage: String?
    var title: String?
    var fallbackImage: String?
    let accessibilityLabel: String
    var accessibilityIdentifier: String?
    var prominent = false
    var size: CGFloat = 48
    var action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                if prominent {
                    Button(action: action, label: label)
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                } else {
                    Button(action: action, label: label)
                        .buttonStyle(.glass)
                }
            } else {
                Button(action: action, label: label)
                    .buttonStyle(.plain)
                    .foregroundStyle(prominent ? Color.white : Color.primary)
                    .background(prominent ? Color.blue : Color.primary.opacity(0.12), in: Circle())
            }
        }
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private func label() -> some View {
        Group {
            if let title {
                Text(title)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            } else {
                Image(systemName: resolvedSymbol)
                    .font(.body.weight(.semibold))
            }
        }
        .frame(width: size, height: size)
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

struct CameraCluster: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        ChromeGlassCluster(spacing: 12) {
            HStack(spacing: 12) {
                GlassIconButton(
                    systemImage: model.isPaused ? "play.fill" : "pause.fill",
                    accessibilityLabel: model.isPaused ? "Resume" : "Pause",
                    accessibilityIdentifier: "openrct2.touch.pause",
                    action: { model.queue(.pause) }
                )
                GlassIconButton(
                    title: model.speedLabel,
                    accessibilityLabel: "Game speed \(model.speedLabel)",
                    accessibilityIdentifier: "openrct2.touch.speed",
                    action: { model.queue(.gameSpeed) }
                )
                GlassIconButton(
                    systemImage: "plus.magnifyingglass",
                    fallbackImage: "plus",
                    accessibilityLabel: "Zoom in",
                    accessibilityIdentifier: "openrct2.touch.zoomIn",
                    action: { model.queue(.zoomIn) }
                )
                GlassIconButton(
                    systemImage: "minus.magnifyingglass",
                    fallbackImage: "minus",
                    accessibilityLabel: "Zoom out",
                    accessibilityIdentifier: "openrct2.touch.zoomOut",
                    action: { model.queue(.zoomOut) }
                )
                GlassIconButton(
                    systemImage: ParkMenuCatalog.rotateViewSymbol,
                    fallbackImage: ParkMenuCatalog.rotateViewFallbackSymbol,
                    accessibilityLabel: "Rotate view",
                    accessibilityIdentifier: "openrct2.touch.rotate",
                    action: { model.queue(.rotateCW) }
                )
            }
        }
        .fixedSize()
        .accessibilityIdentifier("openrct2.touch.cameraCluster")
    }
}

struct StatusStrip: View {
    @ObservedObject var model: ParkChromeModel

    var body: some View {
        HStack(spacing: 16) {
            labeled("banknote", model.cash)
            labeled("person.3.fill", model.guests)
            labeled("star.fill", model.rating)
            labeled("calendar", model.date)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
