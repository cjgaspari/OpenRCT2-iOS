/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

final class ParkChromeModel: ObservableObject {
    @Published var isParkOpen = false
    @Published var isPaused = false
    @Published var speed: UInt8 = 1
    @Published var viewportFlags: UInt32 = 0
    @Published var cash = "—"
    @Published var guests = "—"
    @Published var rating = "—"
    @Published var date = "—"
    @Published var isShowingBuildTools = false
    @Published var isShowingViewTools = false
    @Published var swapBottomControls: Bool {
        didSet {
            UserDefaults.standard.set(swapBottomControls, forKey: Self.swapBottomControlsKey)
        }
    }

    var onAction: ((Int32, Int32) -> Void)?

    private static let swapBottomControlsKey = "openrct2.touch.swapBottomControls"

    init() {
        swapBottomControls = UserDefaults.standard.bool(forKey: Self.swapBottomControlsKey)
    }

    var speedLabel: String {
        "\(max(1, Int(speed)))x"
    }

    func presentBuildTools() {
        isShowingViewTools = false
        isShowingBuildTools = true
    }

    func presentViewTools() {
        isShowingBuildTools = false
        isShowingViewTools = true
    }

    func dismissToolsSheets() {
        isShowingBuildTools = false
        isShowingViewTools = false
    }

    func ensurePaused() {
        guard !isPaused else {
            return
        }
        isPaused = true
        queue(.pause)
    }

    func ensurePlaying() {
        guard isPaused else {
            return
        }
        isPaused = false
        queue(.pause)
    }

    func queueParkMenu(_ action: ParkChromeAction) {
        ensurePlaying()
        queue(action)
    }

    func queue(_ action: ParkChromeAction, extra: Int32 = ParkChromeAction.extraXor) {
        NSLog("[OpenRCT2Touch] native chrome: swift queued action %d extra %d", action.rawValue, extra)
        onAction?(action.rawValue, extra)
    }

    func isToggleOn(_ action: ParkChromeAction) -> Bool {
        switch action {
        case .viewUnderground:
            return viewportFlags & ParkChromeViewportFlag.undergroundInside != 0
        case .viewSeeThroughRides:
            return viewportFlags & ParkChromeViewportFlag.hideRides != 0
        case .viewSeeThroughScenery:
            return viewportFlags & ParkChromeViewportFlag.hideScenery != 0
        case .viewGuests:
            return viewportFlags & ParkChromeViewportFlag.hideGuests == 0
        case .viewStaff:
            return viewportFlags & ParkChromeViewportFlag.hideStaff == 0
        case .viewPathIssues:
            return viewportFlags & ParkChromeViewportFlag.highlightPathIssues != 0
        case .viewHeightMarks:
            return viewportFlags & ParkChromeViewportFlag.heightMarks != 0
        default:
            return false
        }
    }

    func setToggle(_ action: ParkChromeAction, isOn: Bool) {
        applyLocalFlag(action, isOn: isOn)
        queue(action, extra: isOn ? 1 : 0)
    }

    func toggleBinding(for action: ParkChromeAction) -> Binding<Bool> {
        Binding(
            get: { self.isToggleOn(action) },
            set: { self.setToggle(action, isOn: $0) }
        )
    }

    private func applyLocalFlag(_ action: ParkChromeAction, isOn: Bool) {
        switch action {
        case .viewUnderground:
            setFlag(ParkChromeViewportFlag.undergroundInside, enabled: isOn)
        case .viewSeeThroughRides:
            setFlag(ParkChromeViewportFlag.hideRides, enabled: isOn)
        case .viewSeeThroughScenery:
            setFlag(ParkChromeViewportFlag.hideScenery, enabled: isOn)
        case .viewGuests:
            setFlag(ParkChromeViewportFlag.hideGuests, enabled: !isOn)
        case .viewStaff:
            setFlag(ParkChromeViewportFlag.hideStaff, enabled: !isOn)
        case .viewPathIssues:
            setFlag(ParkChromeViewportFlag.highlightPathIssues, enabled: isOn)
        case .viewHeightMarks:
            setFlag(ParkChromeViewportFlag.heightMarks, enabled: isOn)
        default:
            break
        }
    }

    private func setFlag(_ flag: UInt32, enabled: Bool) {
        if enabled {
            viewportFlags |= flag
        } else {
            viewportFlags &= ~flag
        }
    }
}
