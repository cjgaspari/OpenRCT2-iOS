/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Locked UX (CJ): Option 1 gold layered dual-top Liquid Glass — separate
 * horizontal capsules matching kWidgetOrderLeftGroup / RightGroup. No full-span
 * top clear bar. Uniform .glass buttons (Construct ride not prominent).
 * Action codes == WindowTopToolbarWidgetIdx (WIDX_*).
 *****************************************************************************/

import AppKit
import SwiftUI

/// Mirrors `WindowTopToolbarWidgetIdx` in TopToolbar.cpp — do not reorder.
enum MacToolbarWIDX: Int32, CaseIterable, Identifiable {
    case pause = 0
    case fileMenu = 1
    case mute = 2
    case zoomOut = 3
    case zoomIn = 4
    case rotateAntiClockwise = 5
    case rotateClockwise = 6
    case viewMenu = 7
    case map = 8
    case land = 9
    case water = 10
    case scenery = 11
    case path = 12
    case constructRide = 13
    case rides = 14
    case park = 15
    case staff = 16
    case guests = 17
    case clearScenery = 18
    case fastForward = 19
    case cheats = 20
    case debug = 21
    case finances = 22
    case research = 23
    case news = 24
    case network = 25
    case chat = 26

    var id: Int32 { rawValue }

    /// Classic left group order (`kWidgetOrderLeftGroup`) excluding separator.
    static let playback: [MacToolbarWIDX] = [
        .pause, .fastForward, .fileMenu, .mute, .network, .chat, .cheats, .debug,
    ]
    static let camera: [MacToolbarWIDX] = [
        .zoomOut, .zoomIn, .rotateAntiClockwise, .rotateClockwise, .viewMenu, .map,
    ]

    /// Classic right group order (`kWidgetOrderRightGroup`) excluding separator.
    static let construct: [MacToolbarWIDX] = [
        .clearScenery, .land, .water, .scenery, .path, .constructRide,
    ]
    static let manage: [MacToolbarWIDX] = [
        .finances, .research, .rides, .park, .staff, .guests, .news,
    ]

    var help: String {
        switch self {
        case .pause: return "Pause game"
        case .fastForward: return "Game speed"
        case .fileMenu: return "Disc and game options"
        case .mute: return "Mute"
        case .network: return "Multiplayer"
        case .chat: return "Chat"
        case .cheats: return "Cheats"
        case .debug: return "Debug"
        case .zoomOut: return "Zoom out"
        case .zoomIn: return "Zoom in"
        case .rotateAntiClockwise: return "Rotate anti-clockwise"
        case .rotateClockwise: return "Rotate clockwise"
        case .viewMenu: return "View options"
        case .map: return "Show map"
        case .clearScenery: return "Clear scenery"
        case .land: return "Adjust land"
        case .water: return "Adjust water"
        case .scenery: return "Place scenery"
        case .path: return "Build footpath"
        case .constructRide: return "Build ride"
        case .finances: return "Finances"
        case .research: return "Research"
        case .rides: return "Rides in park"
        case .park: return "Park information"
        case .staff: return "Staff"
        case .guests: return "Guests"
        case .news: return "Recent messages"
        }
    }

    /// Prefer g2 in-game PNGs; SF Symbol is fallback only.
    var g2IconName: String? {
        switch self {
        case .mute: return "mute"
        case .fastForward: return "fast_forward"
        case .network: return "multiplayer_toolbar"
        case .chat: return "chat"
        case .cheats: return "cheats"
        case .zoomOut: return "zoom_out"
        case .zoomIn: return "zoom_in"
        case .rotateAntiClockwise: return "rotate_view_anti-clockwise"
        case .viewMenu: return "view"
        case .scenery: return "small_scenery"
        case .path: return "paths"
        case .news: return "news_messages"
        default: return nil
        }
    }

    var sfSymbol: String {
        switch self {
        case .pause: return "pause.fill"
        case .fastForward: return "forward.fill"
        case .fileMenu: return "doc"
        case .mute: return "speaker.wave.2.fill"
        case .network: return "person.3.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .cheats: return "gift.fill"
        case .debug: return "ladybug.fill"
        case .zoomOut: return "minus.magnifyingglass"
        case .zoomIn: return "plus.magnifyingglass"
        case .rotateAntiClockwise: return "rotate.left"
        case .rotateClockwise: return "rotate.right"
        case .viewMenu: return "eye.fill"
        case .map: return "map.fill"
        case .clearScenery: return "trash"
        case .land: return "square.3.layers.3d.top.filled"
        case .water: return "drop.fill"
        case .scenery: return "leaf.fill"
        case .path: return "figure.walk"
        case .constructRide: return "hammer.fill"
        case .finances: return "banknote"
        case .research: return "flask.fill"
        case .rides: return "ferris.wheel"
        case .park: return "building.2.fill"
        case .staff: return "person.badge.shield.checkmark.fill"
        case .guests: return "person.2.fill"
        case .news: return "newspaper.fill"
        }
    }
}

enum GlassChrome {
    static let session = Color.blue
    static let construct = Color.orange
    static let manage = Color.purple
    static let money = Color.green
    static let weather = Color.cyan
    static let clearDimming = Color.black.opacity(0.28)

    static func clearPlate(tint: Color, opacity: Double) -> Glass {
        .clear.tint(tint.opacity(opacity))
    }

    static func statusPlate(tint: Color, opacity: Double) -> Glass {
        .regular.tint(tint.opacity(opacity))
    }
}

/// Loads `resources/g2/icons/<name>.png` when asset path is set from C++.
enum MacToolbarIconStore {
    static var iconDirectory: URL?

    static func image(named name: String) -> NSImage? {
        guard let dir = iconDirectory else { return nil }
        let url = dir.appendingPathComponent("\(name).png")
        return NSImage(contentsOf: url)
    }
}

@MainActor
final class MacParkChromeModel: ObservableObject {
    @Published var statusCash = "—"
    @Published var statusGuests = "—"
    @Published var statusRating = "—"
    @Published var statusDate = "—"
    @Published var statusTemp = "—"
    @Published var statusWeather = "—"
    @Published var isPaused = false
    @Published var isMuted = false
    @Published var speed: UInt8 = 1

    private let onAction: (Int32, Int32) -> Void

    init(onAction: @escaping (Int32, Int32) -> Void) {
        self.onAction = onAction
    }

    func queue(_ widx: MacToolbarWIDX, extra: Int32 = 0) {
        onAction(widx.rawValue, extra)
        if widx == .pause {
            isPaused.toggle()
        }
        if widx == .mute {
            isMuted.toggle()
        }
    }
}

/// Option 1 north star: layered dual-top capsules + bottom ParkInfo / DateInfo.
struct MacParkChromeOverlay: View {
    @ObservedObject var model: MacParkChromeModel

    var body: some View {
        VStack(spacing: 0) {
            topChrome
                .padding(.top, 12)
                .padding(.horizontal, 14)
            Spacer(minLength: 0)
            bottomChrome
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    /// Four capsules matching classic left/right groups + internal separators.
    /// No full-span clear glass across the top.
    private var topChrome: some View {
        HStack(alignment: .center, spacing: 10) {
            GlassToolGroup(
                items: MacToolbarWIDX.playback,
                unionID: "playback",
                plateTint: GlassChrome.session,
                plateOpacity: 0.20,
                model: model
            )
            GlassToolGroup(
                items: MacToolbarWIDX.camera,
                unionID: "camera",
                plateTint: GlassChrome.session,
                plateOpacity: 0.12,
                model: model
            )
            Spacer(minLength: 12)
            GlassToolGroup(
                items: MacToolbarWIDX.construct,
                unionID: "construct",
                plateTint: GlassChrome.construct,
                plateOpacity: 0.18,
                model: model
            )
            GlassToolGroup(
                items: MacToolbarWIDX.manage,
                unionID: "manage",
                plateTint: GlassChrome.manage,
                plateOpacity: 0.14,
                model: model
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openrct2.mac.desktopToolbar")
    }

    private var bottomChrome: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(alignment: .bottom) {
                StatusPanel(
                    cash: model.statusCash,
                    guests: model.statusGuests,
                    rating: model.statusRating
                )
                Spacer()
                DateWeatherPanel(
                    date: model.statusDate,
                    temp: model.statusTemp,
                    weather: model.statusWeather
                )
            }
        }
    }
}

// MARK: - Glass primitives

struct GlassToolGroup: View {
    let items: [MacToolbarWIDX]
    let unionID: String
    var plateTint: Color
    var plateOpacity: Double
    var spacing: CGFloat = 6
    @ObservedObject var model: MacParkChromeModel

    @Namespace private var glassNS

    var body: some View {
        GlassEffectContainer(spacing: spacing + 18) {
            HStack(spacing: spacing) {
                ForEach(items) { widx in
                    GlassToolbarButton(widx: widx, model: model)
                        .glassEffectUnion(id: unionID, namespace: glassNS)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(GlassChrome.clearDimming, in: Capsule())
            .glassEffect(
                GlassChrome.clearPlate(tint: plateTint, opacity: plateOpacity),
                in: .capsule
            )
        }
    }
}

struct GlassToolbarButton: View {
    let widx: MacToolbarWIDX
    @ObservedObject var model: MacParkChromeModel

    var body: some View {
        Button {
            model.queue(widx)
        } label: {
            toolbarGlyph
                .frame(width: 18, height: 18)
        }
        .help(widx.help)
        .accessibilityLabel(widx.help)
        .accessibilityIdentifier("openrct2.mac.widx.\(widx.rawValue)")
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
    }

    @ViewBuilder
    private var toolbarGlyph: some View {
        if let nsImage = resolvedNSImage {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: resolvedSFSymbol)
                .font(.body.weight(.semibold))
        }
    }

    private var resolvedNSImage: NSImage? {
        if widx == .mute, model.isMuted {
            return MacToolbarIconStore.image(named: "unmute")
                ?? MacToolbarIconStore.image(named: "mute")
        }
        if let name = widx.g2IconName {
            return MacToolbarIconStore.image(named: name)
        }
        return nil
    }

    private var resolvedSFSymbol: String {
        if widx == .pause {
            return model.isPaused ? "play.fill" : "pause.fill"
        }
        if widx == .mute {
            return model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        }
        return widx.sfSymbol
    }
}

struct StatusPanel: View {
    let cash: String
    let guests: String
    let rating: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(cash, systemImage: "banknote")
            Label(guests, systemImage: "person.2.fill")
            Label(rating, systemImage: "star.fill")
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(
            GlassChrome.statusPlate(tint: GlassChrome.money, opacity: 0.32),
            in: .rect(cornerRadius: 14)
        )
        .accessibilityIdentifier("openrct2.mac.status")
    }
}

struct DateWeatherPanel: View {
    let date: String
    let temp: String
    let weather: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label(date, systemImage: "calendar")
            Label(temp, systemImage: "thermometer.medium")
            Label(weather, systemImage: "sun.max.fill")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(
            GlassChrome.statusPlate(tint: GlassChrome.weather, opacity: 0.30),
            in: .rect(cornerRadius: 14)
        )
        .accessibilityIdentifier("openrct2.mac.date")
    }
}
