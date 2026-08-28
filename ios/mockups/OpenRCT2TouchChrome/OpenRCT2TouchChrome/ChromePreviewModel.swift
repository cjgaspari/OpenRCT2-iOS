import SwiftUI

enum TopChromeKind: String, CaseIterable, Identifiable {
    case united
    case playHUD
    case island

    var id: String { rawValue }

    var title: String {
        switch self {
        case .united: "Union"
        case .playHUD: "HUD"
        case .island: "Island"
        }
    }

    var subtitle: String {
        switch self {
        case .united:
            "Status and pause share one leading glass capsule. Two menus, one blob."
        case .playHUD:
            "One control: pause, speed, and cash. Park and camera live in that menu."
        case .island:
            "One centered island: pause plus cash and guests. Two menus, one shape."
        }
    }
}

enum BottomChromeKind: String, CaseIterable, Identifiable {
    case split
    case toolbar
    case labeled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "Split"
        case .toolbar: "Bar"
        case .labeled: "Labeled"
        }
    }

    var subtitle: String {
        switch self {
        case .split:
            "Live layout: equal Trees / Build / Paths, and a tools+rotate union on the thumb."
        case .toolbar:
            "One bottom capsule. Build trio and tools/rotate sit in the same glass bar."
        case .labeled:
            "Captioned build tools on the lead corner; vertical tools+rotate on the thumb."
        }
    }
}

@Observable
final class ChromePreviewModel {
    var top: TopChromeKind = .united
    var bottom: BottomChromeKind = .split
    var openWindow: ParkWindow?
    var isPaused = false
    var speed: GameSpeed = .normal
    var isShowingParkTools = false
    var leftHandedControls = false
    var viewFlags: Set<String> = ["Guests", "Rides"]

    /// Cents so the HUD can tick without resizing.
    var cashCents = 1_248_010
    var guests = 248
    var rating = 693
    var date = "Mar 14"

    var cashText: String {
        Self.currency.string(from: NSNumber(value: Double(cashCents) / 100.0)) ?? "$0.00"
    }

    var guestsText: String { "\(guests)" }
    var ratingText: String { "\(rating)" }

    var statusValues: ParkStatusValues {
        ParkStatusValues(
            cash: cashText,
            guests: guestsText,
            rating: ratingText,
            date: date
        )
    }

    var speedLabel: String { speed.multiplierLabel }

    func toolTapped(_ window: ParkWindow) {
        openWindow = window
    }

    func dismissWindowButtonTapped() {
        openWindow = nil
    }

    func pauseButtonTapped() {
        isPaused.toggle()
    }

    func zoomInButtonTapped() {
        toolTapped(.viewOptions)
    }

    func zoomOutButtonTapped() {
        toolTapped(.viewOptions)
    }

    func rotateButtonTapped() {
        toolTapped(.viewOptions)
    }

    func tickStatus() {
        cashCents = max(0, cashCents + Int.random(in: -1_200...2_400))
        guests = max(0, min(9_999, guests + Int.random(in: -2...3)))
        rating = max(0, min(999, rating + Int.random(in: -4...4)))
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

    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
}

enum GameSpeed: String, CaseIterable {
    case normal = "Normal"
    case quick = "Quick"
    case fast = "Fast"
    case turbo = "Turbo"

    var multiplierLabel: String {
        switch self {
        case .normal: "1x"
        case .quick: "2x"
        case .fast: "3x"
        case .turbo: "4x"
        }
    }
}

struct ParkStatusValues: Equatable {
    var cash: String
    var guests: String
    var rating: String
    var date: String
}
