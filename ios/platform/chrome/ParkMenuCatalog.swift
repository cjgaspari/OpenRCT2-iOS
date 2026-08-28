/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import Foundation

struct ParkMenuItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let fallbackImage: String
    let action: ParkChromeAction
}

enum ParkMenuCatalog {
    static let build: [ParkMenuItem] = [
        .init(
            id: "ride", title: "Build ride", subtitle: "New transport, thrill, gentle, shops",
            systemImage: "car.fill", fallbackImage: "car", action: .constructRide),
        .init(
            id: "scenery", title: "Trees & scenery", subtitle: "Gardens, theming, walls",
            systemImage: "tree.fill", fallbackImage: "leaf.fill", action: .scenery),
        .init(
            id: "paths", title: "Paths", subtitle: "Footpaths, queues, additions",
            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
            fallbackImage: "road.lanes", action: .footpath),
        .init(
            id: "land", title: "Land", subtitle: "Raise, lower, and smooth terrain",
            systemImage: "mountain.2.fill", fallbackImage: "triangle.fill", action: .land),
        .init(
            id: "water", title: "Water", subtitle: "Lakes and rivers",
            systemImage: "drop.fill", fallbackImage: "drop", action: .water),
        .init(
            id: "clear", title: "Clear scenery", subtitle: "Remove scenery in a brush",
            systemImage: "eraser", fallbackImage: "xmark.circle", action: .clearScenery),
        .init(
            id: "rides", title: "Ride list", subtitle: "Inspect and manage existing rides",
            systemImage: "tram.fill", fallbackImage: "bus.fill", action: .rideList),
    ]

    static let park: [ParkMenuItem] = [
        .init(
            id: "park", title: "Park info", subtitle: "Name, entrance, awards",
            systemImage: "flag.fill", fallbackImage: "flag", action: .parkInformation),
        .init(
            id: "staff", title: "Staff", subtitle: "Handymen, mechanics, security, entertainers",
            systemImage: "person.badge.shield.checkmark.fill", fallbackImage: "person.fill",
            action: .staffList),
        .init(
            id: "guests", title: "Guests", subtitle: "Thoughts, happiness, and inventory",
            systemImage: "person.3.fill", fallbackImage: "person.2.fill", action: .guestList),
        .init(
            id: "finances", title: "Finances", subtitle: "Cash, loans, and graphs",
            systemImage: "dollarsign.circle.fill", fallbackImage: "creditcard", action: .finances),
        .init(
            id: "research", title: "Research", subtitle: "Funding and invention order",
            systemImage: "flask.fill", fallbackImage: "chart.bar.fill", action: .research),
        .init(
            id: "news", title: "Messages", subtitle: "Park news and objectives",
            systemImage: "newspaper.fill", fallbackImage: "envelope.fill", action: .recentNews),
    ]

    static let view: [ParkMenuItem] = [
        .init(
            id: "map", title: "Map", subtitle: "Overview of the whole park",
            systemImage: "map.fill", fallbackImage: "map", action: .map),
        .init(
            id: "viewOptions", title: "View options", subtitle: "See-through rides, underground, heights",
            systemImage: "eye.fill", fallbackImage: "eye", action: .transparency),
        .init(
            id: "viewport", title: "Extra viewport", subtitle: "A second camera on the park",
            systemImage: "rectangle.split.2x1.fill", fallbackImage: "rectangle.split.2x1",
            action: .extraViewport),
        .init(
            id: "clip", title: "View clipping", subtitle: "Cut the world on a plane",
            systemImage: "square.dashed", fallbackImage: "square", action: .viewClipping),
        .init(
            id: "transparency", title: "Transparency", subtitle: "Fade scenery and supports",
            systemImage: "circle.lefthalf.filled", fallbackImage: "circle", action: .transparency),
    ]

    static let more: [ParkMenuItem] = [
        .init(
            id: "save", title: "Save / Load", subtitle: "File menu from the disc button",
            systemImage: "square.and.arrow.down", fallbackImage: "square.and.arrow.up",
            action: .loadSave),
        .init(
            id: "options", title: "Options", subtitle: "Audio, display, and controls",
            systemImage: "gearshape.fill", fallbackImage: "gear", action: .options),
        .init(
            id: "cheats", title: "Cheats", subtitle: "Sandbox, clearance, and debug",
            systemImage: "wand.and.stars", fallbackImage: "sparkles", action: .cheats),
        .init(
            id: "inspector", title: "Tile inspector", subtitle: "Power-user map cell editor",
            systemImage: "square.grid.3x3.fill", fallbackImage: "square.grid.3x3",
            action: .tileInspector),
        .init(
            id: "about", title: "About", subtitle: "OpenRCT2 credits and version",
            systemImage: "info.circle.fill", fallbackImage: "info.circle", action: .about),
        .init(
            id: "quit", title: "Quit to menu", subtitle: "Return to the title screen",
            systemImage: "rectangle.portrait.and.arrow.right",
            fallbackImage: "arrow.uturn.left", action: .quitToMenu),
    ]

    static let viewWindows: [ParkMenuItem] = view.filter { $0.id != "viewOptions" }
    static let fileAndSettings: [ParkMenuItem] = more.filter { $0.action != .quitToMenu }

    static let viewToggles: [ParkMenuItem] = [
        .init(
            id: "underground", title: "Underground", subtitle: "Look inside from below ground",
            systemImage: "eye.fill", fallbackImage: "eye", action: .viewUnderground),
        .init(
            id: "seeThroughRides", title: "See-through rides", subtitle: "Ghost ride tracks and stations",
            systemImage: "tram.fill", fallbackImage: "tram", action: .viewSeeThroughRides),
        .init(
            id: "seeThroughScenery", title: "See-through scenery", subtitle: "Ghost scenery and theming",
            systemImage: "tree.fill", fallbackImage: "leaf.fill", action: .viewSeeThroughScenery),
        .init(
            id: "showGuests", title: "Guests", subtitle: "Show or hide guests",
            systemImage: "person.3.fill", fallbackImage: "person.fill", action: .viewGuests),
        .init(
            id: "showStaff", title: "Staff", subtitle: "Show or hide staff",
            systemImage: "person.fill", fallbackImage: "person", action: .viewStaff),
        .init(
            id: "pathIssues", title: "Path issues", subtitle: "Highlight broken or blocked paths",
            systemImage: "exclamationmark.triangle.fill", fallbackImage: "exclamationmark.triangle",
            action: .viewPathIssues),
        .init(
            id: "heightMarks", title: "Height marks", subtitle: "Land, track, and path heights",
            systemImage: "ruler.fill", fallbackImage: "ruler", action: .viewHeightMarks),
    ]

    static let constructRideSymbol = "car.fill"
    static let buildSheetSymbol = "hammer.fill"
    static let viewSheetSymbol = "map.fill"
    /// Rotate the isometric viewport 90°. Prefer this over `camera.rotate`.
    static let rotateViewSymbol = "arrow.trianglehead.clockwise.rotate.90"
    static let rotateViewFallbackSymbol = "arrow.triangle.2.circlepath"
}
