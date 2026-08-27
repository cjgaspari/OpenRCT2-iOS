import SwiftUI

enum ParkWindow: String, CaseIterable, Identifiable {
    case constructRide, scenery, footpath, land, water, clearScenery, rideList
    case map, extraViewport, viewClipping, transparency, viewOptions
    case parkInformation, staffList, guestList, finances, research, recentNews
    case loadSave, options, about, cheats, tileInspector

    var id: String { rawValue }

    var title: String {
        switch self {
        case .constructRide: "New Rides"
        case .scenery: "Scenery"
        case .footpath: "Paths"
        case .land: "Land"
        case .water: "Water"
        case .clearScenery: "Clear scenery"
        case .rideList: "Rides"
        case .map: "Map"
        case .extraViewport: "Extra viewport"
        case .viewClipping: "View clipping"
        case .transparency: "Transparency"
        case .viewOptions: "View options"
        case .parkInformation: "Park"
        case .staffList: "Staff"
        case .guestList: "Guests"
        case .finances: "Finances"
        case .research: "Research"
        case .recentNews: "Messages"
        case .loadSave: "Load / Save"
        case .options: "Options"
        case .about: "About"
        case .cheats: "Cheats"
        case .tileInspector: "Tile inspector"
        }
    }
}

struct ParkMenuItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let window: ParkWindow
    var isPrimary = false
}

enum ParkMenuCatalog {
    static let build: [ParkMenuItem] = [
        .init(id: "ride", title: "Build ride", subtitle: "New transport, thrill, gentle, shops", systemImage: "plus", window: .constructRide, isPrimary: true),
        .init(id: "scenery", title: "Trees & scenery", subtitle: "Gardens, theming, walls", systemImage: "tree.fill", window: .scenery),
        .init(id: "paths", title: "Paths", subtitle: "Footpaths, queues, additions", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath", window: .footpath),
        .init(id: "land", title: "Land", subtitle: "Raise, lower, and smooth terrain", systemImage: "mountain.2.fill", window: .land),
        .init(id: "water", title: "Water", subtitle: "Lakes and rivers", systemImage: "drop.fill", window: .water),
        .init(id: "clear", title: "Clear scenery", subtitle: "Remove scenery in a brush", systemImage: "eraser", window: .clearScenery),
        .init(id: "rides", title: "Ride list", subtitle: "Inspect and manage existing rides", systemImage: "tram.fill", window: .rideList),
    ]

    static let park: [ParkMenuItem] = [
        .init(id: "park", title: "Park info", subtitle: "Name, entrance, awards", systemImage: "flag.fill", window: .parkInformation),
        .init(id: "staff", title: "Staff", subtitle: "Handymen, mechanics, security, entertainers", systemImage: "person.badge.shield.checkmark.fill", window: .staffList),
        .init(id: "guests", title: "Guests", subtitle: "Thoughts, happiness, and inventory", systemImage: "person.3.fill", window: .guestList),
        .init(id: "finances", title: "Finances", subtitle: "Cash, loans, and graphs", systemImage: "dollarsign.circle.fill", window: .finances),
        .init(id: "research", title: "Research", subtitle: "Funding and invention order", systemImage: "flask.fill", window: .research),
        .init(id: "news", title: "Messages", subtitle: "Park news and objectives", systemImage: "newspaper.fill", window: .recentNews),
    ]

    static let view: [ParkMenuItem] = [
        .init(id: "map", title: "Map", subtitle: "Overview of the whole park", systemImage: "map.fill", window: .map),
        .init(id: "viewOptions", title: "View options", subtitle: "See-through rides, underground, heights", systemImage: "eye.fill", window: .viewOptions),
        .init(id: "viewport", title: "Extra viewport", subtitle: "A second camera on the park", systemImage: "rectangle.split.2x1.fill", window: .extraViewport),
        .init(id: "clip", title: "View clipping", subtitle: "Cut the world on a plane", systemImage: "square.dashed", window: .viewClipping),
        .init(id: "transparency", title: "Transparency", subtitle: "Fade scenery and supports", systemImage: "circle.lefthalf.filled", window: .transparency),
    ]

    static let more: [ParkMenuItem] = [
        .init(id: "save", title: "Save / Load", subtitle: "File menu from the disc button", systemImage: "square.and.arrow.down", window: .loadSave),
        .init(id: "options", title: "Options", subtitle: "Audio, display, and controls", systemImage: "gearshape.fill", window: .options),
        .init(id: "cheats", title: "Cheats", subtitle: "Sandbox, clearance, and debug", systemImage: "wand.and.stars", window: .cheats),
        .init(id: "inspector", title: "Tile inspector", subtitle: "Power-user map cell editor", systemImage: "square.grid.3x3.fill", window: .tileInspector),
        .init(id: "about", title: "About", subtitle: "OpenRCT2 credits and version", systemImage: "info.circle.fill", window: .about),
    ]

    static let alwaysBuild = Array(build.prefix(3))
    static let cameraSymbols = ["plus.magnifyingglass", "minus.magnifyingglass", "camera.rotate"]
    static let viewToggles = [
        "Underground", "See-through rides", "See-through scenery",
        "Guests", "Staff", "Path issues", "Height marks",
    ]
}
