/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI
import UIKit

@_cdecl("OpenRCT2TouchChromeAttach")
func OpenRCT2TouchChromeAttach(
    _ parentViewPtr: UnsafeMutableRawPointer?,
    _ onAction: (@convention(c) (Int32, Int32) -> Void)?
) -> UnsafeMutableRawPointer? {
    guard let parentViewPtr, let onAction else {
        return nil
    }
    let parent = Unmanaged<UIView>.fromOpaque(parentViewPtr).takeUnretainedValue()
    let session = ParkChromeSession(onAction: onAction)
    session.attach(to: parent)
    return Unmanaged.passRetained(session).toOpaque()
}

@_cdecl("OpenRCT2TouchChromeDetach")
func OpenRCT2TouchChromeDetach(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else {
        return
    }
    let session = Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr).takeRetainedValue()
    session.detach()
}

@_cdecl("OpenRCT2TouchChromeSetParkOpen")
func OpenRCT2TouchChromeSetParkOpen(_ sessionPtr: UnsafeMutableRawPointer?, _ open: Bool) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().setParkOpen(open)
}

@_cdecl("OpenRCT2TouchChromeSetState")
func OpenRCT2TouchChromeSetState(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ paused: Bool,
    _ speed: UInt8,
    _ flags: UInt32
) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .setState(paused: paused, speed: speed, flags: flags)
}

@_cdecl("OpenRCT2TouchChromeSetStatus")
func OpenRCT2TouchChromeSetStatus(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ cash: UnsafePointer<CChar>?,
    _ guests: UnsafePointer<CChar>?,
    _ rating: UnsafePointer<CChar>?,
    _ date: UnsafePointer<CChar>?
) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().setStatus(
        cash: cash.map { String(cString: $0) } ?? "—",
        guests: guests.map { String(cString: $0) } ?? "—",
        rating: rating.map { String(cString: $0) } ?? "—",
        date: date.map { String(cString: $0) } ?? "—"
    )
}

@_cdecl("OpenRCT2TouchChromePresentScenarioPicker")
func OpenRCT2TouchChromePresentScenarioPicker(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ snapshotJSON: UnsafePointer<CChar>?
) {
    guard let sessionPtr, let snapshotJSON else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .presentScenarioPicker(snapshotJSON: String(cString: snapshotJSON))
}

@_cdecl("OpenRCT2TouchChromeDismissScenarioPicker")
func OpenRCT2TouchChromeDismissScenarioPicker(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .dismissScenarioPicker()
}

@_cdecl("OpenRCT2TouchChromeSetScenarioPreviewLoading")
func OpenRCT2TouchChromeSetScenarioPreviewLoading(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ scenarioID: Int32,
    _ loading: Bool
) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .setScenarioPreviewLoading(scenarioID: scenarioID, loading: loading)
}

@_cdecl("OpenRCT2TouchChromeSetScenarioPreview")
func OpenRCT2TouchChromeSetScenarioPreview(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ scenarioID: Int32,
    _ rgba: UnsafePointer<UInt8>?,
    _ width: Int32,
    _ height: Int32
) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .setScenarioPreview(scenarioID: scenarioID, rgba: rgba, width: width, height: height)
}

@_cdecl("OpenRCT2TouchChromeBringToFront")
func OpenRCT2TouchChromeBringToFront(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().bringToFront()
}

@_cdecl("OpenRCT2TouchChromePresentLoadSave")
func OpenRCT2TouchChromePresentLoadSave(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ snapshotJSON: UnsafePointer<CChar>?
) {
    guard let sessionPtr, let snapshotJSON else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .presentLoadSave(snapshotJSON: String(cString: snapshotJSON))
}

@_cdecl("OpenRCT2TouchChromeDismissLoadSave")
func OpenRCT2TouchChromeDismissLoadSave(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .dismissLoadSave()
}

@_cdecl("OpenRCT2TouchChromeCopyPendingSaveName")
func OpenRCT2TouchChromeCopyPendingSaveName(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ length: Int32
) -> Bool {
    guard let sessionPtr else {
        return false
    }
    return Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr)
        .takeUnretainedValue()
        .copyPendingSaveName(into: buffer, length: length)
}
