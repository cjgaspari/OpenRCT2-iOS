/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Dense Options (2.1) + Cheats (2.7) Mac windows — classic top tabs, small controls.
 *****************************************************************************/

import AppKit
import SwiftUI

// MARK: - Config / Cheats C bridges

@_silgen_name("OpenRCT2MacNativeConfigGetBool")
func OpenRCT2MacNativeConfigGetBool(_ key: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeConfigSetBool")
func OpenRCT2MacNativeConfigSetBool(_ key: Int32, _ value: Bool)
@_silgen_name("OpenRCT2MacNativeConfigSave")
func OpenRCT2MacNativeConfigSave()

@_silgen_name("OpenRCT2MacNativeCheatGet")
func OpenRCT2MacNativeCheatGet(_ type: Int32) -> Bool
@_silgen_name("OpenRCT2MacNativeCheatToggle")
func OpenRCT2MacNativeCheatToggle(_ type: Int32)
@_silgen_name("OpenRCT2MacNativeCheatRun")
func OpenRCT2MacNativeCheatRun(_ type: Int32, _ p1: Int64, _ p2: Int64)

// Config bool keys — must match MacNativeUI.mm
private enum MacConfigKey: Int32 {
    case uncapFPS = 0
    case useVSync = 1
    case showFPS = 2
    case landscapeSmoothing = 3
    case alwaysShowGridlines = 4
    case dayNightCycle = 5
    case enableLightFx = 6
    case renderWeatherEffects = 7
    case renderWeatherGloom = 8
    case transparentWater = 9
    case showGuestPurchases = 10
    case edgeScrolling = 11
    case invertViewportDrag = 12
    case zoomToCursor = 13
    case trapCursor = 14
    case toolbarShowFinances = 15
    case toolbarShowResearch = 16
    case toolbarShowCheats = 17
    case toolbarShowNews = 18
    case toolbarShowMute = 19
    case toolbarShowChat = 20
    case toolbarShowZoom = 21
    case masterSoundEnabled = 22
    case soundEnabled = 23
    case rideMusicEnabled = 24
    case audioFocus = 25
    case debuggingTools = 26
    case autoStaffPlacement = 27
    case autoOpenShops = 28
    case showRealNamesOfGuests = 29
    case showRealNamesOfStaff = 30
    case confirmationPrompt = 31
    case allowEarlyCompletion = 32
}

// CheatType raw values — must match Cheats.h
private enum MacCheatType: Int32 {
    case sandboxMode = 0
    case disableClearanceChecks = 1
    case disableSupportLimits = 2
    case showAllOperatingModes = 3
    case showVehiclesFromOtherTrackTypes = 4
    case disableTrainLengthLimit = 5
    case enableChainLiftOnAllTrack = 6
    case disableBrakesFailure = 8
    case disableAllBreakdowns = 9
    case buildInPauseMode = 11
    case ignoreRideIntensity = 12
    case disableVandalism = 13
    case disableLittering = 14
    case noMoney = 15
    case freezeWeather = 36
    case neverendingMarketing = 40
    case allowArbitraryRideTypeChanges = 41
    case disableRideValueAging = 43
    case ignoreResearchStatus = 44
    case enableAllDrawableTrackPieces = 45
    case allowTrackPlaceInvalidHeights = 48
    case allowRegularPathAsQueue = 50
    case allowSpecialColourSchemes = 51
    case ignorePrice = 53
    case disableGrassGrowing = 54
    case disablePlantAging = 25
    case makeDestructible = 30 // CheatsState.makeAllDestructible via makeDestructible
}

// MARK: - Options (2.1)

enum MacOptionsPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Options",
            size: NSSize(width: 420, height: 380),
            root: OptionsView()
        )
        return true
    }
}

private struct OptionsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case display = "Display"
        case rendering = "Rendering"
        case audio = "Audio"
        case interface = "Interface"
        case controls = "Controls"
        case misc = "Misc"
        case advanced = "Advanced"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .display

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Form {
                switch tab {
                case .display:
                    configToggle("Uncap FPS", .uncapFPS)
                    configToggle("VSync", .useVSync)
                    configToggle("Show FPS", .showFPS)
                case .rendering:
                    configToggle("Landscape smoothing", .landscapeSmoothing)
                    configToggle("Always show gridlines", .alwaysShowGridlines)
                    configToggle("Day/night cycle", .dayNightCycle)
                    configToggle("Light FX", .enableLightFx)
                    configToggle("Weather effects", .renderWeatherEffects)
                    configToggle("Weather gloom", .renderWeatherGloom)
                    configToggle("Transparent water", .transparentWater)
                    configToggle("Show guest purchases", .showGuestPurchases)
                case .audio:
                    configToggle("Master sound", .masterSoundEnabled)
                    configToggle("Sound effects", .soundEnabled)
                    configToggle("Ride music", .rideMusicEnabled)
                    configToggle("Audio focus", .audioFocus)
                case .interface:
                    configToggle("Toolbar: Finances", .toolbarShowFinances)
                    configToggle("Toolbar: Research", .toolbarShowResearch)
                    configToggle("Toolbar: Cheats", .toolbarShowCheats)
                    configToggle("Toolbar: News", .toolbarShowNews)
                    configToggle("Toolbar: Mute", .toolbarShowMute)
                    configToggle("Toolbar: Chat", .toolbarShowChat)
                    configToggle("Toolbar: Zoom", .toolbarShowZoom)
                case .controls:
                    configToggle("Edge scrolling", .edgeScrolling)
                    configToggle("Invert viewport drag", .invertViewportDrag)
                    configToggle("Zoom to cursor", .zoomToCursor)
                    configToggle("Trap cursor", .trapCursor)
                case .misc:
                    configToggle("Auto staff placement", .autoStaffPlacement)
                    configToggle("Auto-open shops", .autoOpenShops)
                    configToggle("Real guest names", .showRealNamesOfGuests)
                    configToggle("Real staff names", .showRealNamesOfStaff)
                    configToggle("Confirmation prompt", .confirmationPrompt)
                case .advanced:
                    configToggle("Debugging tools", .debuggingTools)
                    configToggle("Allow early completion", .allowEarlyCompletion)
                }
            }
            .formStyle(.grouped)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func configToggle(_ title: String, _ key: MacConfigKey) -> some View {
        Toggle(title, isOn: Binding(
            get: { OpenRCT2MacNativeConfigGetBool(key.rawValue) },
            set: { v in
                OpenRCT2MacNativeConfigSetBool(key.rawValue, v)
                OpenRCT2MacNativeConfigSave()
            }
        ))
        .controlSize(.small)
    }
}

@_cdecl("OpenRCT2MacNativeOptionsShow")
func OpenRCT2MacNativeOptionsShow() -> Bool {
    MainActor.assumeIsolated { MacOptionsPanel.show() }
}

// MARK: - Cheats (2.7)

enum MacCheatsPanel {
    @MainActor private static var panel: NSPanel?

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return true
        }
        panel = MacDensePanelHost.present(
            title: "Cheats",
            size: NSSize(width: 380, height: 420),
            root: CheatsView()
        )
        return true
    }
}

private struct CheatsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case money = "Money"
        case park = "Park"
        case rides = "Rides"
        case guests = "Guests"
        case weather = "Weather"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .money
    @State private var tick = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Form {
                switch tab {
                case .money:
                    cheatToggle("No money", .noMoney)
                    cheatToggle("Ignore price", .ignorePrice)
                    Button("Clear loan") { OpenRCT2MacNativeCheatRun(18, 0, 0) } // clearLoan
                        .controlSize(.small)
                    Button("Add money") { OpenRCT2MacNativeCheatRun(16, 1000, 0) } // addMoney
                        .controlSize(.small)
                case .park:
                    cheatToggle("Sandbox mode", .sandboxMode)
                    cheatToggle("Disable clearance checks", .disableClearanceChecks)
                    cheatToggle("Disable support limits", .disableSupportLimits)
                    cheatToggle("Build in pause mode", .buildInPauseMode)
                    cheatToggle("Neverending marketing", .neverendingMarketing)
                    cheatToggle("Disable grass growing", .disableGrassGrowing)
                    cheatToggle("Disable plant aging", .disablePlantAging)
                    cheatToggle("Disable vandalism", .disableVandalism)
                    cheatToggle("Disable littering", .disableLittering)
                    Button("Own all land") { OpenRCT2MacNativeCheatRun(42, 0, 0) }
                        .controlSize(.small)
                    Button("Remove litter") { OpenRCT2MacNativeCheatRun(27, 0, 0) }
                        .controlSize(.small)
                    Button("Fix vandalism") { OpenRCT2MacNativeCheatRun(26, 0, 0) }
                        .controlSize(.small)
                    Button("Win scenario") { OpenRCT2MacNativeCheatRun(34, 0, 0) }
                        .controlSize(.small)
                case .rides:
                    cheatToggle("Unlock operating modes", .showAllOperatingModes)
                    cheatToggle("Vehicles from other tracks", .showVehiclesFromOtherTrackTypes)
                    cheatToggle("Disable train length limit", .disableTrainLengthLimit)
                    cheatToggle("Chain lift on all track", .enableChainLiftOnAllTrack)
                    cheatToggle("Disable brakes failure", .disableBrakesFailure)
                    cheatToggle("Disable all breakdowns", .disableAllBreakdowns)
                    cheatToggle("Ignore ride intensity", .ignoreRideIntensity)
                    cheatToggle("All drawable track pieces", .enableAllDrawableTrackPieces)
                    cheatToggle("Allow invalid heights", .allowTrackPlaceInvalidHeights)
                    cheatToggle("Arbitrary ride type changes", .allowArbitraryRideTypeChanges)
                    cheatToggle("Disable ride value aging", .disableRideValueAging)
                    cheatToggle("Ignore research status", .ignoreResearchStatus)
                    cheatToggle("Make all destructible", .makeDestructible)
                    Button("Renew rides") { OpenRCT2MacNativeCheatRun(29, 0, 0) }
                        .controlSize(.small)
                    Button("Fix rides") { OpenRCT2MacNativeCheatRun(31, 0, 0) }
                        .controlSize(.small)
                case .guests:
                    Button("Remove all guests") { OpenRCT2MacNativeCheatRun(21, 0, 0) }
                        .controlSize(.small)
                    Button("Generate tram (250)") { OpenRCT2MacNativeCheatRun(20, 250, 0) }
                        .controlSize(.small)
                case .weather:
                    cheatToggle("Freeze weather", .freezeWeather)
                }
            }
            .formStyle(.grouped)
            .controlSize(.small)
            .id(tick)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func cheatToggle(_ title: String, _ type: MacCheatType) -> some View {
        Toggle(title, isOn: Binding(
            get: { OpenRCT2MacNativeCheatGet(type.rawValue) },
            set: { _ in
                OpenRCT2MacNativeCheatToggle(type.rawValue)
                tick &+= 1
            }
        ))
        .controlSize(.small)
    }
}

@_cdecl("OpenRCT2MacNativeCheatsShow")
func OpenRCT2MacNativeCheatsShow() -> Bool {
    MainActor.assumeIsolated { MacCheatsPanel.show() }
}
