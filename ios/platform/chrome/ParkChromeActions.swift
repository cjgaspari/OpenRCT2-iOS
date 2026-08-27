/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import Foundation

/// Keep these values in sync with `ParkChromeActions.h`.
enum ParkChromeAction: Int32 {
    case constructRide = 1
    case scenery = 2
    case footpath = 3
    case land = 4
    case water = 5
    case clearScenery = 6
    case rideList = 7
    case parkInformation = 8
    case staffList = 9
    case guestList = 10
    case finances = 11
    case research = 12
    case recentNews = 13
    case map = 14
    case extraViewport = 15
    case viewClipping = 16
    case transparency = 17
    case loadSave = 18
    case options = 19
    case about = 20
    case cheats = 21
    case tileInspector = 22
    case pause = 23
    case gameSpeed = 24
    case zoomIn = 25
    case zoomOut = 26
    case rotateCW = 27
    case viewUnderground = 28
    case viewSeeThroughRides = 29
    case viewSeeThroughScenery = 30
    case viewGuests = 31
    case viewStaff = 32
    case viewPathIssues = 33
    case viewHeightMarks = 34

    static let extraXor: Int32 = -1
}

enum ParkChromeViewportFlag {
    static let undergroundInside: UInt32 = 1 << 0
    static let hideRides: UInt32 = 1 << 1
    static let hideScenery: UInt32 = 1 << 2
    static let hideGuests: UInt32 = 1 << 11
    static let landHeights: UInt32 = 1 << 4
    static let trackHeights: UInt32 = 1 << 5
    static let pathHeights: UInt32 = 1 << 6
    static let highlightPathIssues: UInt32 = 1 << 18
    static let hideStaff: UInt32 = 1 << 23
    static let heightMarks: UInt32 = landHeights | trackHeights | pathHeights
}
