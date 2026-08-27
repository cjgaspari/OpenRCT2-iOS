import SwiftUI

enum ChromeMockup: String, CaseIterable, Identifiable {
    case floatingCluster
    case trailingRail
    case morphingFAB
    case findMySheet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .floatingCluster: "Cluster"
        case .trailingRail: "Rail"
        case .morphingFAB: "FAB"
        case .findMySheet: "Sheet"
        }
    }

    var subtitle: String {
        switch self {
        case .floatingCluster: "Floating bottom glass cluster"
        case .trailingRail: "Maps-style trailing tool rail"
        case .morphingFAB: "Morphing build FAB"
        case .findMySheet: "Find My sheet + tabs"
        }
    }
}

enum GameSpeed: String, CaseIterable {
    case normal = "Normal"
    case quick = "Quick"
    case fast = "Fast"
    case turbo = "Turbo"

    var symbol: String {
        switch self {
        case .normal: "play.fill"
        case .quick: "forward.fill"
        case .fast: "forward.end.fill"
        case .turbo: "forward.end.alt.fill"
        }
    }
}

enum SheetTab: String, CaseIterable, Identifiable {
    case build, park, view, more
    var id: String { rawValue }

    var title: String {
        switch self {
        case .build: "Build"
        case .park: "Park"
        case .view: "View"
        case .more: "More"
        }
    }

    var symbol: String {
        switch self {
        case .build: "hammer.fill"
        case .park: "flag.fill"
        case .view: "eye.fill"
        case .more: "ellipsis"
        }
    }
}

@Observable
final class ChromePreviewModel {
    var mockup: ChromeMockup = .floatingCluster
    var openWindow: ParkWindow?
    var isPaused = false
    var speed: GameSpeed = .normal
    var isFABExpanded = false
    var sheetDetent: PresentationDetent = .height(220)
    var sheetTab: SheetTab = .build
    var viewFlags: Set<String> = ["Guests", "Rides"]

    static let compactSheetHeight: CGFloat = 220

    func mockupSelected(_ mockup: ChromeMockup) {
        self.mockup = mockup
        isFABExpanded = false
        if mockup == .findMySheet {
            sheetDetent = .height(Self.compactSheetHeight)
        }
    }

    func toolTapped(_ window: ParkWindow) {
        openWindow = window
    }

    func dismissWindowButtonTapped() {
        openWindow = nil
    }

    func pauseButtonTapped() {
        isPaused.toggle()
    }

    func speedButtonTapped() {
        speed = GameSpeed.allCases[(GameSpeed.allCases.firstIndex(of: speed)! + 1) % GameSpeed.allCases.count]
    }

    func fabButtonTapped() {
        isFABExpanded.toggle()
    }

    func viewFlagToggled(_ name: String) {
        if viewFlags.contains(name) {
            viewFlags.remove(name)
        } else {
            viewFlags.insert(name)
        }
    }

    subscript(viewFlag name: String) -> Bool {
        get { viewFlags.contains(name) }
        set {
            if newValue {
                viewFlags.insert(name)
            } else {
                viewFlags.remove(name)
            }
        }
    }
}
