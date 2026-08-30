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
    var model: ParkChromeModel
    var usesOwnGlass = true
    @State private var frozenSpeed: UInt8?

    var body: some View {
        Menu {
            PauseSpeedMenuItems(model: model)
                .onDisappear { frozenSpeed = nil }
        } label: {
            PauseControlLabel(model: model, frozenSpeed: frozenSpeed)
        }
        .modifier(PlaybackMenuChrome(usesOwnGlass: usesOwnGlass))
        .fixedSize()
        .transaction { $0.animation = nil }
        .simultaneousGesture(TapGesture().onEnded {
            frozenSpeed = model.speed
        })
        .accessibilityLabel("Pause, speed, and more")
        .accessibilityHint("Opens pause, speed, and more")
        .accessibilityIdentifier("openrct2.touch.playbackMenu")
    }
}

/// Lives outside the `Menu` container so the menu itself does not observe speed.
private struct PauseControlLabel: View {
    var model: ParkChromeModel
    var frozenSpeed: UInt8?

    var body: some View {
        let speed = frozenSpeed ?? model.speed
        Group {
            if model.isPaused {
                Image(systemName: "play.fill")
            } else if speed > 1 {
                Text("\(max(1, Int(speed)))x")
                    .monospacedDigit()
            } else {
                Image(systemName: "pause.fill")
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(minWidth: 32)
    }
}

private struct PauseSpeedMenuItems: View {
    var model: ParkChromeModel
    @State private var speedChoice: UInt8 = 1

    var body: some View {
        Group {
            Button {
                if model.isPaused {
                    model.ensurePlaying()
                } else {
                    model.ensurePaused()
                }
            } label: {
                Label(model.isPaused ? "Resume" : "Pause", systemImage: model.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityIdentifier("openrct2.touch.pause")

            Menu("Game Speed") {
                Picker("Game Speed", selection: $speedChoice) {
                    Text("1x").tag(UInt8(1))
                    Text("2x").tag(UInt8(2))
                    Text("3x").tag(UInt8(3))
                    Text("4x").tag(UInt8(4))
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("openrct2.touch.speed")
            }

            Section("More") {
                ForEach(ParkMenuCatalog.fileAndSettings) { item in
                    Button {
                        model.queueParkMenu(item.action)
                    } label: {
                        ParkMenuLabel(item: item)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    model.queue(.quitToMenu)
                } label: {
                    ParkMenuLabel(item: ParkMenuCatalog.quitToMenu)
                }
            }
        }
        .onAppear {
            speedChoice = max(1, min(4, model.speed))
        }
        .onChange(of: speedChoice) { _, newValue in
            let clamped = max(UInt8(1), min(UInt8(4), newValue))
            if clamped == model.speed {
                return
            }
            model.queue(.gameSpeed, extra: Int32(clamped))
        }
    }
}

/// Status on the leading edge and pause on the trailing edge, each in its own
/// glass capsule. Used by the SwiftUI preview tree; the live overlay pins the
/// two controls with Auto Layout so they stay apart across rotations.
struct TopChromeBar: View {
    var model: ParkChromeModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusMenu(model: model)
            Spacer(minLength: 8)
            PauseSpeedMenu(model: model)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openrct2.touch.topChrome")
    }
}

/// View and rotate share one Liquid Glass capsule on the lead thumb.
/// Portrait (regular height) stacks View over rotate; compact-height landscape
/// lays them out horizontally so both stay reachable on a short screen.
struct ViewRotateCluster: View {
    var model: ParkChromeModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Namespace private var unionNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            clusterLayout {
                unionedIcon(
                    systemImage: ParkMenuCatalog.viewSheetSymbol,
                    label: "View",
                    identifier: "openrct2.touch.viewSheet"
                ) {
                    model.presentViewTools()
                }
                unionedIcon(
                    systemImage: ParkMenuCatalog.rotateViewSymbol,
                    label: "Rotate view",
                    identifier: "openrct2.touch.rotate"
                ) {
                    model.queue(.rotateCW)
                }
            }
        }
        .fixedSize()
        .accessibilityIdentifier("openrct2.touch.viewRotate")
    }

    private var clusterLayout: AnyLayout {
        verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))
    }

    private func unionedIcon(
        systemImage: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .imageScale(.medium)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .glassEffect()
                .glassEffectUnion(id: "viewRotate", namespace: unionNamespace)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

/// Build control on the trailing thumb.
struct BuildCluster: View {
    @Bindable var model: ParkChromeModel

    var body: some View {
        Button {
            model.presentBuildTools()
        } label: {
            Image(systemName: ParkMenuCatalog.buildSheetSymbol)
                .font(.body.weight(.semibold))
                .imageScale(.medium)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .glassEffect(.regular.interactive())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Build")
        .accessibilityHint("Opens ride, scenery, paths, and terrain tools")
        .accessibilityIdentifier("openrct2.touch.buildSheet")
        .sheet(isPresented: $model.isShowingBuildTools) {
            BuildToolsSheet(model: model)
        }
    }
}

/// Tappable park status. Opens a `Menu` (tap, not long-press) with Park windows.
struct StatusMenu: View {
    var model: ParkChromeModel
    var usesOwnGlass = true
    var fillsWidth = false
    @State private var frozenTicker: ParkTickerSnapshot?

    var body: some View {
        Menu {
            StatusMenuItems(model: model)
                .onDisappear { frozenTicker = nil }
        } label: {
            StatusStripLabel(model: model, frozen: frozenTicker)
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        }
        .modifier(PlaybackMenuChrome(usesOwnGlass: usesOwnGlass))
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .transaction { $0.animation = nil }
        .simultaneousGesture(TapGesture().onEnded {
            frozenTicker = ParkTickerSnapshot(model)
        })
        .accessibilityLabel("Park information")
        .accessibilityHint("Opens park information")
        .accessibilityIdentifier("openrct2.touch.statusStrip")
    }
}

private struct StatusMenuItems: View {
    var model: ParkChromeModel

    var body: some View {
        Section("Park") {
            ForEach(ParkMenuCatalog.park) { item in
                Button {
                    model.queueParkMenu(item.action)
                } label: {
                    ParkMenuLabel(item: item)
                }
            }
        }
    }
}

private struct ParkTickerSnapshot: Equatable {
    var cash: String
    var guests: String
    var rating: String
    var date: String

    init(_ model: ParkChromeModel) {
        cash = model.cash
        guests = model.guests
        rating = model.rating
        date = model.date
    }
}

private struct StatusStripLabel: View {
    var model: ParkChromeModel
    var frozen: ParkTickerSnapshot?

    var body: some View {
        let ticker = frozen ?? ParkTickerSnapshot(model)
        ViewThatFits(in: .horizontal) {
            metrics(ticker, includeGuests: true, includeRatingAndDate: true)
            metrics(ticker, includeGuests: true, includeRatingAndDate: false)
            metrics(ticker, includeGuests: false, includeRatingAndDate: false)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private func metrics(
        _ ticker: ParkTickerSnapshot,
        includeGuests: Bool,
        includeRatingAndDate: Bool
    ) -> some View {
        HStack(spacing: 6) {
            statusItem("banknote", ticker.cash, prototype: "$9,999,999.99", color: .green)
                .layoutPriority(1)
            if includeGuests {
                statusItem("person.3.fill", ticker.guests, prototype: "9999", color: .purple)
            }
            if includeRatingAndDate {
                statusItem("star.fill", ticker.rating, prototype: "9999", color: .yellow)
                calendarItem(ticker.date)
            }
        }
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

/// Tabular figures plus a hidden prototype string keep live values from
/// resizing the capsule.
private struct TabularStatusValue: View {
    let text: String
    let prototype: String

    var body: some View {
        ZStack(alignment: .leading) {
            Text(prototype)
                .hidden()
            Text(text)
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
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
        if prominent {
            content.buttonStyle(.glass).tint(.blue)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

private struct PlaybackMenuChrome: ViewModifier {
    var usesOwnGlass = true

    func body(content: Content) -> some View {
        if usesOwnGlass {
            content
                .menuOrder(.fixed)
                .menuStyle(.button)
                .buttonBorderShape(.capsule)
                .buttonStyle(.glass)
        } else {
            content
                .menuOrder(.fixed)
                .menuStyle(.button)
                .buttonStyle(.plain)
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
            ParkChromeSymbol(item: item)
        }
    }
}

struct ParkMenuLabel: View {
    let item: ParkMenuItem

    var body: some View {
        // Plain SF Symbol so the icon adopts the menu's label colour in light/dark.
        Label(item.title, systemImage: item.systemImage)
    }
}

/// Palette when the symbol has two layers (snow cap, canopy/trunk, water highlight);
/// hierarchical otherwise so a single tint still has depth.
struct ParkChromeSymbol: View {
    let systemImage: String
    var primary: Color
    var secondary: Color?

    init(systemImage: String, primary: Color, secondary: Color? = nil) {
        self.systemImage = systemImage
        self.primary = primary
        self.secondary = secondary
    }

    init(item: ParkMenuItem) {
        let style = ParkChromeSymbolStyle.colors(for: item.id)
        self.systemImage = item.systemImage
        self.primary = style.primary
        self.secondary = style.secondary
    }

    var body: some View {
        let image = Image(systemName: systemImage)
        if let secondary {
            image
                .symbolRenderingMode(.palette)
                .foregroundStyle(primary, secondary)
        } else {
            image
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(primary)
        }
    }
}

private enum ParkChromeSymbolStyle {
    static func colors(for id: String) -> (primary: Color, secondary: Color?) {
        switch id {
        case "ride":
            return (.blue, .cyan)
        case "scenery", "seeThroughScenery":
            return (.green, .mint)
        case "paths":
            return (.brown, .gray)
        case "land":
            return (.white, Color(red: 0.45, green: 0.28, blue: 0.14))
        case "water":
            return (.blue, .teal)
        case "clear":
            return (.orange, .yellow)
        case "rides", "seeThroughRides":
            return (.indigo, .purple)
        case "park":
            return (.green, .yellow)
        case "staff", "showStaff":
            return (.blue, .indigo)
        case "guests", "showGuests":
            return (.purple, .pink)
        case "finances":
            return (.green, .mint)
        case "research":
            return (.teal, .purple)
        case "news":
            return (.blue, .gray)
        case "map":
            return (.green, .brown)
        case "viewOptions":
            return (.blue, .cyan)
        case "viewport":
            return (.indigo, .blue)
        case "clip":
            return (.gray, nil)
        case "transparency":
            return (.purple, .blue)
        case "underground":
            return (.brown, .gray)
        case "pathIssues":
            return (.orange, .red)
        case "heightMarks":
            return (.yellow, .brown)
        case "save":
            return (.blue, .cyan)
        case "options":
            return (.gray, .blue)
        case "cheats":
            return (.purple, .pink)
        case "inspector":
            return (.orange, .yellow)
        case "about":
            return (.blue, .cyan)
        case "quit":
            return (.red, nil)
        default:
            return (.accentColor, nil)
        }
    }
}
