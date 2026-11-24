/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import AppKit
import SwiftUI

/// Action codes mirror the Touch chrome enum for future engine wiring.
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

/// Full park HUD roles: status, pause, view/rotate, build — Mac-native SwiftUI.
struct MacParkChromeOverlay: View {
    @ObservedObject var model: MacParkChromeModel

    var body: some View {
        ZStack {
            Color.clear
            VStack {
                HStack(alignment: .top, spacing: 12) {
                    statusCluster
                    Spacer(minLength: 8)
                    pauseControl
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 16) {
                    viewRotateCluster
                    Spacer(minLength: 8)
                    buildControl
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private var statusCluster: some View {
        Menu {
            Button("Park Information") { model.queue(.viewMenu, extra: 8) }
            Button("Finances") { model.queue(.viewMenu, extra: 11) }
            Button("Guests") { model.queue(.viewMenu, extra: 10) }
        } label: {
            HStack(spacing: 10) {
                labeledMetric("banknote", model.statusCash, .green)
                labeledMetric("person.2.fill", model.statusGuests, .purple)
                labeledMetric("star.fill", model.statusRating, .yellow)
                labeledMetric("calendar", model.statusDate, .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .accessibilityLabel("Park status")
        .accessibilityIdentifier("openrct2.mac.status")
    }

    private func labeledMetric(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var pauseControl: some View {
        Button {
            model.queue(.pause)
        } label: {
            Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(model.isPaused ? "Resume" : "Pause")
        .accessibilityIdentifier("openrct2.mac.pause")
    }

    private var viewRotateCluster: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    model.queue(.viewMenu)
                } label: {
                    Image(systemName: "eye")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("View options")
                .accessibilityIdentifier("openrct2.mac.view")

                Button {
                    model.queue(.rotateCW)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Rotate view")
                .accessibilityIdentifier("openrct2.mac.rotate")

                Button {
                    model.queue(.zoomIn)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Zoom in")

                Button {
                    model.queue(.zoomOut)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Zoom out")
            }
        }
    }

    private var buildControl: some View {
        Button {
            model.queue(.buildNewRide)
        } label: {
            Image(systemName: "hammer.fill")
                .font(.title3.weight(.semibold))
        }
        .buttonStyle(.glassProminent)
        .tint(.orange)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel("Build")
        .accessibilityIdentifier("openrct2.mac.build")
    }
}
