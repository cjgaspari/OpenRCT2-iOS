/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import AppKit
import SwiftUI

/// Action codes aligned with park chrome roles (status / pause / view / rotate / build).
enum MacChromeAction: Int32 {
    case pause = 23
    case zoomIn = 25
    case zoomOut = 26
    case rotateCW = 27
    case buildNewRide = 1
    case viewMenu = 1001
}

@MainActor
final class MacParkChromeModel: ObservableObject {
    @Published var statusCash = "—"
    @Published var statusGuests = "—"
    @Published var statusRating = "—"
    @Published var statusDate = "—"
    @Published var isPaused = false
    @Published var speed: UInt8 = 1

    private let onAction: (Int32, Int32) -> Void

    init(onAction: @escaping (Int32, Int32) -> Void) {
        self.onAction = onAction
    }

    func queue(_ action: MacChromeAction, extra: Int32 = 0) {
        onAction(action.rawValue, extra)
        if action == .pause {
            isPaused.toggle()
        }
    }
}

/// Mac desktop chrome: floating Liquid Glass pill under the title bar.
/// Same roles as Touch conceptually; layout is a centered desktop accessory
/// panel (not iPhone corner HUD, not a harsh edge-to-edge strip).
struct MacParkChromeOverlay: View {
    @ObservedObject var model: MacParkChromeModel

    var body: some View {
        VStack(spacing: 0) {
            floatingToolbar
                .padding(.top, 14)
                .padding(.horizontal, 48)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(true)
    }

    private var floatingToolbar: some View {
        HStack(spacing: 12) {
            statusCluster

            toolbarGlyph(
                model.isPaused ? "play.fill" : "pause.fill",
                label: model.isPaused ? "Resume" : "Pause"
            ) {
                model.queue(.pause)
            }
            .accessibilityIdentifier("openrct2.mac.pause")

            Divider()
                .frame(height: 16)

            HStack(spacing: 6) {
                toolbarGlyph("eye", label: "View") { model.queue(.viewMenu) }
                toolbarGlyph("arrow.triangle.2.circlepath", label: "Rotate") { model.queue(.rotateCW) }
                toolbarGlyph("plus.magnifyingglass", label: "Zoom in") { model.queue(.zoomIn) }
                toolbarGlyph("minus.magnifyingglass", label: "Zoom out") { model.queue(.zoomOut) }
            }

            Spacer(minLength: 10)

            Button {
                model.queue(.buildNewRide)
            } label: {
                Label("Build", systemImage: "hammer.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
            .accessibilityIdentifier("openrct2.mac.build")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openrct2.mac.desktopToolbar")
    }

    private var statusCluster: some View {
        Menu {
            Button("Park Information") { model.queue(.viewMenu, extra: 8) }
            Button("Finances") { model.queue(.viewMenu, extra: 11) }
            Button("Guests") { model.queue(.viewMenu, extra: 10) }
        } label: {
            HStack(spacing: 12) {
                labeledMetric("banknote", model.statusCash)
                labeledMetric("person.2.fill", model.statusGuests)
                labeledMetric("star.fill", model.statusRating)
                labeledMetric("calendar", model.statusDate)
            }
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .accessibilityLabel("Park status")
        .accessibilityIdentifier("openrct2.mac.status")
    }

    private func labeledMetric(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption.weight(.medium).monospacedDigit())
        }
    }

    private func toolbarGlyph(
        _ systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}
