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

    /// Options order: left groups then right groups (every glass toolbar icon).
    static var optionsList: [MacToolbarWIDX] {
        playback + camera + construct + manage
    }

    private var visibilityDefaultsKey: String {
        "openrct2.mac.ui.toolbar.visible.\(rawValue)"
    }

    /// Glass visibility: UserDefaults override, else classic config seed / on.
    var isShownByConfig: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: visibilityDefaultsKey) != nil {
            return defaults.bool(forKey: visibilityDefaultsKey)
        }
        return classicSeedVisible
    }

    /// Classic Options seeds for optional buttons; everything else defaults on.
    private var classicSeedVisible: Bool {
        switch self {
        case .mute:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowMute.rawValue)
        case .chat:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowChat.rawValue)
        case .research:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowResearch.rawValue)
        case .cheats:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowCheats.rawValue)
        case .news:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowNews.rawValue)
        case .zoomIn, .zoomOut:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowZoom.rawValue)
        case .rotateAntiClockwise:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowRotateAnticlockwise.rawValue)
        case .finances:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.toolbarShowFinances.rawValue)
        case .debug:
            return OpenRCT2MacNativeConfigGetBool(MacConfigKey.debuggingTools.rawValue)
        default:
            return true
        }
    }

    private var classicConfigKey: MacConfigKey? {
        switch self {
        case .mute: return .toolbarShowMute
        case .chat: return .toolbarShowChat
        case .research: return .toolbarShowResearch
        case .cheats: return .toolbarShowCheats
        case .news: return .toolbarShowNews
        case .zoomIn, .zoomOut: return .toolbarShowZoom
        case .rotateAntiClockwise: return .toolbarShowRotateAnticlockwise
        case .finances: return .toolbarShowFinances
        case .debug: return .debuggingTools
        default: return nil
        }
    }

    func setShownByConfig(_ shown: Bool) {
        let defaults = UserDefaults.standard
        switch self {
        case .zoomIn, .zoomOut:
            // Classic zoom is one flag for both buttons.
            defaults.set(shown, forKey: MacToolbarWIDX.zoomIn.visibilityDefaultsKey)
            defaults.set(shown, forKey: MacToolbarWIDX.zoomOut.visibilityDefaultsKey)
        default:
            defaults.set(shown, forKey: visibilityDefaultsKey)
        }
        if let classicConfigKey {
            OpenRCT2MacNativeConfigSetBool(classicConfigKey.rawValue, shown)
            OpenRCT2MacNativeConfigSave()
        }
        NotificationCenter.default.post(name: .openRCT2MacChromePrefsDidChange, object: nil)
    }

    var shownBinding: Binding<Bool> {
        Binding(
            get: { self.isShownByConfig },
            set: { self.setShownByConfig($0) }
        )
    }

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

/// Loads cleaned toolbar sprites / g2 icons from directories set by C++.
enum MacToolbarIconStore {
    static var iconDirectory: URL?
    static var cleanedSpriteDirectory: URL?

    static func image(named name: String) -> NSImage? {
        if let cleaned = cleanedSpriteDirectory {
            let url = cleaned.appendingPathComponent("\(name).png")
            if let img = NSImage(contentsOf: url) { return img }
        }
        guard let dir = iconDirectory else { return nil }
        return NSImage(contentsOf: dir.appendingPathComponent("\(name).png"))
    }

    /// Prefer WIDX-named cleaned sprite, then g2 alias.
    static func image(for widx: MacToolbarWIDX, muted: Bool) -> NSImage? {
        if widx == .mute {
            if muted, let u = image(named: "unmute") ?? image(named: "widx_mute_off") { return u }
            if let m = image(named: "mute") ?? image(named: "widx_mute") { return m }
        }
        if let named = image(named: "widx_\(widx.rawValue)") { return named }
        if let g2 = widx.g2IconName, let img = image(named: g2) { return img }
        return nil
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
    @Published var iconMode: MacToolbarIconMode = MacToolbarIconMode.current
    @Published var versionString: String = "OpenRCT2"
    /// In-game glass HUD (toolbar + status). Off on title or when UI Lab disables parkChrome.
    @Published var showParkChrome: Bool = true
    /// Native title/startup chrome. Off when UI Lab reverts title to classic.
    @Published var showTitleChrome: Bool = false

    /// Liquid Glass toast (news ticker + errors). Edge from Options / UI Lab.
    @Published var toastKind: MacToastKind = .news
    @Published var toastMessage: String = ""
    @Published var toastVisible: Bool = false
    @Published var toastShowSubject: Bool = false
    @Published var toastShowLocate: Bool = false
    /// Bumped when Options / UI Lab chrome prefs change (toolbar icons, toast edge).
    @Published var prefsEpoch: UInt = 0

    private let onAction: (Int32, Int32) -> Void
    private var errorDismissTask: Task<Void, Never>?
    private var prefsObserver: NSObjectProtocol?

    init(onAction: @escaping (Int32, Int32) -> Void) {
        self.onAction = onAction
        MenuTarget.shared.onIconModeChanged = { [weak self] in
            self?.iconMode = MacToolbarIconMode.current
        }
        prefsObserver = NotificationCenter.default.addObserver(
            forName: .openRCT2MacChromePrefsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.prefsEpoch &+= 1
            }
        }
    }

    deinit {
        if let prefsObserver {
            NotificationCenter.default.removeObserver(prefsObserver)
        }
    }

    func setNewsToast(message: String, showSubject: Bool, showLocate: Bool) {
        // Error toasts win until auto-dismiss; don't clobber with empty news.
        if toastVisible, toastKind == .error { return }
        if message.isEmpty {
            if toastKind == .news {
                toastVisible = false
                toastMessage = ""
            }
            return
        }
        toastKind = .news
        toastMessage = message
        toastShowSubject = showSubject
        toastShowLocate = showLocate
        toastVisible = true
    }

    func setErrorToast(message: String, autoDismissSeconds: Double = 8) {
        errorDismissTask?.cancel()
        toastKind = .error
        toastMessage = message
        toastShowSubject = false
        toastShowLocate = false
        toastVisible = true
        errorDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoDismissSeconds))
            guard !Task.isCancelled else { return }
            if toastKind == .error {
                toastVisible = false
                toastMessage = ""
            }
        }
    }

    func dismissToast() {
        errorDismissTask?.cancel()
        toastVisible = false
        toastMessage = ""
    }

    func toastSubject() {
        onAction(MacChromeToastAction.subject.rawValue, 0)
    }

    func toastLocate() {
        onAction(MacChromeToastAction.locate.rawValue, 0)
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

    func queueTitle(_ action: MacChromeTitleAction, extra: Int32 = 0) {
        onAction(action.rawValue, extra)
    }

    func forwardMenuCode(_ code: Int32, extra: Int32 = 0) {
        onAction(code, extra)
    }

    func setVersion(_ version: String) {
        versionString = version
        MacAboutPanel.versionString = version
    }

    func handleToolbarClick(_ widx: MacToolbarWIDX, buttonView: NSView?) {
        if MacToolbarMenus.isMenuWidget(widx) {
            MacToolbarMenus.popUp(for: widx, relativeTo: buttonView) { [weak self] index in
                guard let self else { return }
                if widx == .fileMenu, index == 9 {
                    MacAboutPanel.show()
                    return
                }
                self.queue(widx, extra: index)
            }
            return
        }
        queue(widx)
    }
}

/// Extra chrome action codes (outside WIDX_* range) for toast / title buttons.
enum MacChromeToastAction: Int32 {
    case subject = 10001
    case locate = 10002
}

/// Option 1 north star: layered dual-top capsules + bottom ParkInfo / DateInfo.
struct MacParkChromeOverlay: View {
    @ObservedObject var model: MacParkChromeModel

    var body: some View {
        Group {
            if model.showTitleChrome {
                // Classic title layout fills the window (logo/options/actions/exit/version).
                MacTitleChromeLayout(model: model)
            } else {
                VStack(spacing: 0) {
                    if model.showParkChrome {
                        VStack(spacing: 6) {
                            if toastEdge == .top {
                                toastBar(edge: .top)
                            }
                            topChrome
                        }
                        .scaleEffect(chromeScale, anchor: .top)
                        // scaleEffect doesn't expand layout — pad so hits/park stay clear.
                        .padding(.bottom, max(0, (chromeScale - 1) * 52))
                        .padding(.top, 4)
                        .padding(.horizontal, 14)
                    }
                    Spacer(minLength: 0)
                    if model.showParkChrome {
                        bottomChrome
                            .scaleEffect(chromeScale, anchor: .bottom)
                            .padding(.top, max(0, (chromeScale - 1) * 90))
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                }
                .animation(.snappy, value: model.toastVisible)
                .animation(.snappy, value: toastEdge)
                .animation(.snappy, value: chromeScale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private var toastEdge: MacNewsToastEdge {
        _ = model.prefsEpoch
        return MacUILabPrefs.shared.newsToastEdge
    }

    /// 1.0 = default smallest glass HUD; independent of classic `window_scale`.
    private var chromeScale: CGFloat {
        _ = model.prefsEpoch
        return CGFloat(MacUILabPrefs.shared.glassChromeScale)
    }

    /// Four capsules matching classic left/right groups + internal separators.
    /// No full-span clear glass across the top. Icons honor Options → Interface.
    private var topChrome: some View {
        let _ = model.prefsEpoch
        return HStack(alignment: .center, spacing: 10) {
            toolGroup(
                MacToolbarWIDX.playback,
                unionID: "playback",
                tint: GlassChrome.session,
                opacity: 0.20
            )
            toolGroup(
                MacToolbarWIDX.camera,
                unionID: "camera",
                tint: GlassChrome.session,
                opacity: 0.12
            )
            Spacer(minLength: 12)
            toolGroup(
                MacToolbarWIDX.construct,
                unionID: "construct",
                tint: GlassChrome.construct,
                opacity: 0.18
            )
            toolGroup(
                MacToolbarWIDX.manage,
                unionID: "manage",
                tint: GlassChrome.manage,
                opacity: 0.14
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openrct2.mac.desktopToolbar")
    }

    @ViewBuilder
    private func toolGroup(
        _ items: [MacToolbarWIDX],
        unionID: String,
        tint: Color,
        opacity: Double
    ) -> some View {
        let visible = items.filter(\.isShownByConfig)
        if !visible.isEmpty {
            GlassToolGroup(
                items: visible,
                unionID: unionID,
                plateTint: tint,
                plateOpacity: opacity,
                model: model
            )
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            if toastEdge == .bottom {
                toastBar(edge: .bottom)
            }
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

    @ViewBuilder
    private func toastBar(edge: MacNewsToastEdge) -> some View {
        if model.toastVisible, !model.toastMessage.isEmpty {
            MacGlassToastBar(
                kind: model.toastKind,
                message: model.toastMessage,
                showSubject: model.toastShowSubject,
                showLocate: model.toastShowLocate,
                onSubject: { model.toastSubject() },
                onLocate: { model.toastLocate() },
                onDismiss: { model.dismissToast() }
            )
            .frame(maxWidth: .infinity)
            .transition(.move(edge: edge == .top ? .top : .bottom).combined(with: .opacity))
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
        // Outer scale lives on the chrome stack; keep intrinsic button metrics at 1× here.
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
    @State private var anchor = ToolbarButtonAnchor()

    var body: some View {
        Button {
            model.handleToolbarClick(widx, buttonView: anchor.view)
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
        .background(ToolbarButtonAnchorReader(anchor: anchor))
    }

    @ViewBuilder
    private var toolbarGlyph: some View {
        let preferNative = model.iconMode == .nativeInGame
        if preferNative, let nsImage = MacToolbarIconStore.image(for: widx, muted: model.isMuted) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: resolvedSFSymbol)
                .font(.body.weight(.semibold))
        }
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

/// Captures the AppKit view under a glass button so NSMenu can pop up relative to it.
final class ToolbarButtonAnchor {
    weak var view: NSView?
}

struct ToolbarButtonAnchorReader: NSViewRepresentable {
    let anchor: ToolbarButtonAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { anchor.view = view }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { anchor.view = nsView }
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
