/*****************************************************************************
 * Research mockup — FULL desktop TopToolbar as Liquid Glass.
 * Gold standard: Option 2 — horizontal layered clear glass, tint/opacity,
 * GlassEffectContainer + glassEffectUnion. No vertical tool rails.
 *****************************************************************************/

import AppKit
import SwiftUI

@main
struct MacLiquidGlassLayoutsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(width: 1440, height: 900)
    }
}

/// Only horizontal, Option-2-styled layouts. Vertical rails removed.
enum LayoutOption: String, CaseIterable, Identifiable {
    /// Gold standard — single dual top clear-glass band + bottom status.
    case layeredDualTop
    /// Same glass language; tools split into L/R top corner plates.
    case cornerPlates
    /// Same glass language; one continuous top band, status also on bg glass.
    case fullBand

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .layeredDualTop: return "1"
        case .cornerPlates: return "2"
        case .fullBand: return "3"
        }
    }

    var title: String {
        switch self {
        case .layeredDualTop: return "Gold — layered dual top"
        case .cornerPlates: return "Corner plates + bg glass"
        case .fullBand: return "Full top band + status glass"
        }
    }
}

/// Semantic glass palette — tint sparingly (HIG: one primary, status accents).
enum GlassChrome {
    static let primaryAction = Color.orange
    static let money = Color.green
    static let weather = Color.cyan
    static let session = Color.blue
    static let construct = Color.orange
    static let manage = Color.purple

    static func clearPlate(tint: Color, opacity: Double = 0.22) -> Glass {
        .clear.tint(tint.opacity(opacity))
    }

    static func statusPlate(tint: Color, opacity: Double = 0.28) -> Glass {
        .regular.tint(tint.opacity(opacity))
    }

    /// HIG: ~35% dark dim under clear glass when content is bright.
    static let clearDimming = Color.black.opacity(0.28)
}

struct RootView: View {
    @State private var option: LayoutOption = .layeredDualTop

    var body: some View {
        NavigationStack {
            ZStack {
                parkBackground
                layoutOverlay
                    .padding(16)
            }
            .frame(minWidth: 1280, minHeight: 800)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Layout", selection: $option) {
                        ForEach(LayoutOption.allCases) { item in
                            Text(item.shortLabel).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                ToolbarItem(placement: .primaryAction) {
                    Text("\(option.shortLabel) — \(option.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationTitle("Desktop chrome → Liquid Glass")
        }
    }

    @ViewBuilder
    private var layoutOverlay: some View {
        switch option {
        case .layeredDualTop:
            LayoutLayeredDualTop()
        case .cornerPlates:
            LayoutCornerPlates()
        case .fullBand:
            LayoutFullBand()
        }
    }

    private var parkBackground: some View {
        Group {
            if let image = parkNSImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.42, blue: 0.28),
                        Color(red: 0.10, green: 0.22, blue: 0.18),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var parkNSImage: NSImage? {
        if let url = Bundle.module.url(forResource: "ParkBackground", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return Bundle.module.image(forResource: "ParkBackground")
    }
}

// MARK: - Tool catalog (full TopToolbar inventory)

struct ToolItem: Identifiable {
    let id: String
    let symbol: String
    let help: String
}

enum DesktopTools {
    static let playback: [ToolItem] = [
        .init(id: "pause", symbol: "pause.fill", help: "Pause"),
        .init(id: "speed", symbol: "forward.fill", help: "Game speed"),
        .init(id: "file", symbol: "doc", help: "File / options"),
        .init(id: "mute", symbol: "speaker.wave.2.fill", help: "Mute"),
        .init(id: "network", symbol: "person.3.fill", help: "Network"),
        .init(id: "chat", symbol: "bubble.left.and.bubble.right.fill", help: "Chat"),
        .init(id: "cheats", symbol: "gift.fill", help: "Cheats"),
        .init(id: "debug", symbol: "ladybug.fill", help: "Debug"),
    ]

    static let camera: [ToolItem] = [
        .init(id: "zoomOut", symbol: "minus.magnifyingglass", help: "Zoom out"),
        .init(id: "zoomIn", symbol: "plus.magnifyingglass", help: "Zoom in"),
        .init(id: "rotACW", symbol: "rotate.left", help: "Rotate anti-clockwise"),
        .init(id: "rotCW", symbol: "rotate.right", help: "Rotate clockwise"),
        .init(id: "view", symbol: "eye.fill", help: "View options"),
        .init(id: "map", symbol: "map.fill", help: "Map"),
    ]

    static let construct: [ToolItem] = [
        .init(id: "clear", symbol: "trash", help: "Clear scenery"),
        .init(id: "land", symbol: "square.3.layers.3d.top.filled", help: "Land"),
        .init(id: "water", symbol: "drop.fill", help: "Water"),
        .init(id: "scenery", symbol: "leaf.fill", help: "Scenery"),
        .init(id: "path", symbol: "figure.walk", help: "Paths"),
        .init(id: "ride", symbol: "hammer.fill", help: "Construct ride"),
    ]

    static let manage: [ToolItem] = [
        .init(id: "finances", symbol: "banknote", help: "Finances"),
        .init(id: "research", symbol: "flask.fill", help: "Research"),
        .init(id: "rides", symbol: "ferris.wheel", help: "Rides"),
        .init(id: "park", symbol: "building.2.fill", help: "Park information"),
        .init(id: "staff", symbol: "person.badge.shield.checkmark.fill", help: "Staff"),
        .init(id: "guests", symbol: "person.2.fill", help: "Guests"),
        .init(id: "news", symbol: "newspaper.fill", help: "News"),
    ]
}

// MARK: - Gold-standard glass primitives (from former Option 2)

struct GlassToolButton: View {
    let item: ToolItem
    var prominent = false
    var tint: Color? = nil

    var body: some View {
        Button {} label: {
            Image(systemName: item.symbol)
        }
        .help(item.help)
        .accessibilityLabel(item.help)
        .modifier(GlassToolChrome(prominent: prominent, tint: tint))
    }
}

private struct GlassToolChrome: ViewModifier {
    var prominent: Bool
    var tint: Color?

    func body(content: Content) -> some View {
        if prominent {
            content
                .buttonStyle(.glassProminent)
                .tint(tint ?? GlassChrome.primaryAction)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
        } else {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
        }
    }
}

/// Horizontal semantic tool group — clear tinted plate + unioned glass buttons.
struct GlassToolGroup: View {
    let items: [ToolItem]
    let unionID: String
    var plateTint: Color = GlassChrome.session
    var plateOpacity: Double = 0.18
    var prominentID: String? = nil
    var prominentTint: Color = GlassChrome.primaryAction
    var spacing: CGFloat = 6

    @Namespace private var glassNS

    var body: some View {
        // Container spacing > stack spacing → shapes blend at rest (Apple docs).
        GlassEffectContainer(spacing: spacing + 18) {
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    GlassToolButton(
                        item: item,
                        prominent: item.id == prominentID,
                        tint: item.id == prominentID ? prominentTint : nil
                    )
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

/// Outer clear plate over park media (gold-standard background glass).
struct GlassBackgroundPlate<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var dimmingOpacity: Double = 0.55
    var glassTintOpacity: Double = 0.08
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                GlassChrome.clearDimming.opacity(dimmingOpacity),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .glassEffect(
                .clear.tint(Color.white.opacity(glassTintOpacity)),
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

struct StatusPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("$10,000.00", systemImage: "banknote")
            Label("0 guests", systemImage: "person.2.fill")
            Label("Park rating", systemImage: "star.fill")
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(
            GlassChrome.statusPlate(tint: GlassChrome.money, opacity: 0.32),
            in: .rect(cornerRadius: 14)
        )
    }
}

struct DateWeatherPanel: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label("March 4, Year 1", systemImage: "calendar")
            Label("13°C", systemImage: "thermometer.medium")
            Label("Clear", systemImage: "sun.max.fill")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(
            GlassChrome.statusPlate(tint: GlassChrome.weather, opacity: 0.30),
            in: .rect(cornerRadius: 14)
        )
    }
}

/// Shared leading / trailing horizontal tool rows (never vertical rails).
struct SessionToolRow: View {
    var body: some View {
        HStack(spacing: 10) {
            GlassToolGroup(
                items: DesktopTools.playback,
                unionID: "playback",
                plateTint: GlassChrome.session,
                plateOpacity: 0.20
            )
            GlassToolGroup(
                items: DesktopTools.camera,
                unionID: "camera",
                plateTint: GlassChrome.session,
                plateOpacity: 0.12
            )
        }
    }
}

struct BuildManageToolRow: View {
    var body: some View {
        HStack(spacing: 10) {
            GlassToolGroup(
                items: DesktopTools.construct,
                unionID: "construct",
                plateTint: GlassChrome.construct,
                plateOpacity: 0.24,
                prominentID: "ride"
            )
            GlassToolGroup(
                items: DesktopTools.manage,
                unionID: "manage",
                plateTint: GlassChrome.manage,
                plateOpacity: 0.14
            )
        }
    }
}

struct BottomStatusRow: View {
    var withBackgroundGlass = false

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(alignment: .bottom) {
                if withBackgroundGlass {
                    GlassBackgroundPlate(cornerRadius: 18, dimmingOpacity: 0.45) {
                        StatusPanel()
                    }
                } else {
                    StatusPanel()
                }
                Spacer()
                if withBackgroundGlass {
                    GlassBackgroundPlate(cornerRadius: 18, dimmingOpacity: 0.45) {
                        DateWeatherPanel()
                    }
                } else {
                    DateWeatherPanel()
                }
            }
        }
    }
}

// MARK: - 1 Gold standard (former Option 2)

struct LayoutLayeredDualTop: View {
    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 28) {
                GlassBackgroundPlate {
                    HStack(alignment: .center, spacing: 12) {
                        SessionToolRow()
                        Spacer(minLength: 16)
                        BuildManageToolRow()
                    }
                }
            }
            Spacer()
            BottomStatusRow()
        }
    }
}

// MARK: - 2 Same glass; separate L/R top corner plates + bottom bg glass

struct LayoutCornerPlates: View {
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 14) {
                GlassEffectContainer(spacing: 22) {
                    GlassBackgroundPlate(cornerRadius: 20) {
                        SessionToolRow()
                    }
                }
                Spacer(minLength: 8)
                GlassEffectContainer(spacing: 22) {
                    GlassBackgroundPlate(cornerRadius: 20) {
                        BuildManageToolRow()
                    }
                }
            }
            Spacer()
            BottomStatusRow(withBackgroundGlass: true)
        }
    }
}

// MARK: - 3 Same glass; continuous top band; status also on bg glass

struct LayoutFullBand: View {
    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 28) {
                GlassBackgroundPlate {
                    HStack(alignment: .center, spacing: 12) {
                        SessionToolRow()
                        Spacer(minLength: 16)
                        BuildManageToolRow()
                    }
                }
            }
            Spacer()
            BottomStatusRow(withBackgroundGlass: true)
        }
    }
}
