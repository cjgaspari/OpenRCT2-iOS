/*****************************************************************************
 * Research mockup — FULL desktop TopToolbar inventory as real Liquid Glass.
 * Not a Touch HUD port. Uses Mac width.
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

enum LayoutOption: String, CaseIterable, Identifiable {
    case classicMapped
    case denserTop
    case splitRails
    case topAndBottomStatus

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .classicMapped: return "1"
        case .denserTop: return "2"
        case .splitRails: return "3"
        case .topAndBottomStatus: return "4"
        }
    }

    var title: String {
        switch self {
        case .classicMapped: return "Classic groups → glass"
        case .denserTop: return "Dense dual top bars"
        case .splitRails: return "L/R rails + bottom status"
        case .topAndBottomStatus: return "Full top + bottom status"
        }
    }
}

struct RootView: View {
    @State private var option: LayoutOption = .classicMapped

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
                    .frame(width: 160)
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
        case .classicMapped:
            LayoutClassicMapped()
        case .denserTop:
            LayoutDenserTop()
        case .splitRails:
            LayoutSplitRails()
        case .topAndBottomStatus:
            LayoutTopAndBottomStatus()
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
    // Left group — playback / session
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

    // Left group — camera / view
    static let camera: [ToolItem] = [
        .init(id: "zoomOut", symbol: "minus.magnifyingglass", help: "Zoom out"),
        .init(id: "zoomIn", symbol: "plus.magnifyingglass", help: "Zoom in"),
        .init(id: "rotACW", symbol: "rotate.left", help: "Rotate anti-clockwise"),
        .init(id: "rotCW", symbol: "rotate.right", help: "Rotate clockwise"),
        .init(id: "view", symbol: "eye.fill", help: "View options"),
        .init(id: "map", symbol: "map.fill", help: "Map"),
    ]

    // Right group — construction
    static let construct: [ToolItem] = [
        .init(id: "clear", symbol: "trash", help: "Clear scenery"),
        .init(id: "land", symbol: "square.3.layers.3d.top.filled", help: "Land"),
        .init(id: "water", symbol: "drop.fill", help: "Water"),
        .init(id: "scenery", symbol: "leaf.fill", help: "Scenery"),
        .init(id: "path", symbol: "figure.walk", help: "Paths"),
        .init(id: "ride", symbol: "hammer.fill", help: "Construct ride"),
    ]

    // Right group — management
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

// MARK: - Glass primitives

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
                .tint(tint ?? .orange)
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

struct GlassToolCluster: View {
    let items: [ToolItem]
    var prominentID: String? = nil
    var spacing: CGFloat = 6

    var body: some View {
        GlassEffectContainer(spacing: spacing + 4) {
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    GlassToolButton(
                        item: item,
                        prominent: item.id == prominentID,
                        tint: item.id == prominentID ? .orange : nil
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
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
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Layout 1: classic left/right groups mirrored as glass (uses width)

struct LayoutClassicMapped: View {
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    GlassToolCluster(items: DesktopTools.playback)
                    GlassToolCluster(items: DesktopTools.camera)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 8) {
                    GlassToolCluster(items: DesktopTools.construct, prominentID: "ride")
                    GlassToolCluster(items: DesktopTools.manage)
                }
            }
            Spacer()
            HStack(alignment: .bottom) {
                StatusPanel()
                Spacer()
                DateWeatherPanel()
            }
        }
    }
}

// MARK: - Layout 2: denser single top bands (maximum horizontal use)

struct LayoutDenserTop: View {
    var body: some View {
        VStack {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(DesktopTools.playback) { GlassToolButton(item: $0) }
                    Divider().frame(height: 22)
                    ForEach(DesktopTools.camera) { GlassToolButton(item: $0) }
                    Spacer(minLength: 12)
                    ForEach(DesktopTools.construct) { item in
                        GlassToolButton(item: item, prominent: item.id == "ride", tint: .orange)
                    }
                    Divider().frame(height: 22)
                    ForEach(DesktopTools.manage) { GlassToolButton(item: $0) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
            Spacer()
            HStack(alignment: .bottom) {
                StatusPanel()
                Spacer()
                DateWeatherPanel()
            }
        }
    }
}

// MARK: - Layout 3: vertical rails on L/R (uses height + width)

struct LayoutSplitRails: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(spacing: 8) {
                rail(DesktopTools.playback)
                rail(DesktopTools.camera)
                Spacer()
                StatusPanel()
            }
            Spacer()
            VStack(spacing: 8) {
                rail(DesktopTools.construct, prominentID: "ride")
                rail(DesktopTools.manage)
                Spacer()
                DateWeatherPanel()
            }
        }
    }

    private func rail(_ items: [ToolItem], prominentID: String? = nil) -> some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    GlassToolButton(
                        item: item,
                        prominent: item.id == prominentID,
                        tint: item.id == prominentID ? .orange : nil
                    )
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Layout 4: full top strip + prominent bottom status (status-forward)

struct LayoutTopAndBottomStatus: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                GlassToolCluster(items: DesktopTools.playback + DesktopTools.camera)
                Spacer(minLength: 8)
                GlassToolCluster(items: DesktopTools.construct, prominentID: "ride")
                GlassToolCluster(items: DesktopTools.manage)
            }
            Spacer()
            HStack(spacing: 16) {
                StatusPanel()
                    .frame(maxWidth: 280, alignment: .leading)
                Spacer()
                DateWeatherPanel()
                    .frame(maxWidth: 280, alignment: .trailing)
            }
        }
    }
}
