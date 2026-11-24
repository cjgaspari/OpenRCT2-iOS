/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import AppKit
import Foundation

@_cdecl("OpenRCT2MacChromeAttach")
func OpenRCT2MacChromeAttach(
    _ contentViewPtr: UnsafeMutableRawPointer?,
    _ onAction: (@convention(c) (Int32, Int32) -> Void)?
) -> UnsafeMutableRawPointer? {
    guard let contentViewPtr, let onAction else {
        return nil
    }
    return MainActor.assumeIsolated {
        let parent = Unmanaged<NSView>.fromOpaque(contentViewPtr).takeUnretainedValue()
        let session = MacParkChromeSession(onAction: onAction)
        session.attach(to: parent)
        return Unmanaged.passRetained(session).toOpaque()
    }
}

@_cdecl("OpenRCT2MacChromeDetach")
func OpenRCT2MacChromeDetach(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else { return }
    MainActor.assumeIsolated {
        let session = Unmanaged<MacParkChromeSession>.fromOpaque(sessionPtr).takeRetainedValue()
        session.detach()
    }
}

@_cdecl("OpenRCT2MacChromeBringToFront")
func OpenRCT2MacChromeBringToFront(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else { return }
    MainActor.assumeIsolated {
        Unmanaged<MacParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().bringToFront()
    }
}

@_cdecl("OpenRCT2MacChromeSetIconPath")
func OpenRCT2MacChromeSetIconPath(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ path: UnsafePointer<CChar>?
) {
    guard let sessionPtr, let path else { return }
    let pathStr = String(cString: path)
    MainActor.assumeIsolated {
        Unmanaged<MacParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue()
            .setIconDirectory(pathStr)
    }
}

@_cdecl("OpenRCT2MacChromeSetStatus")
func OpenRCT2MacChromeSetStatus(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ cash: UnsafePointer<CChar>?,
    _ guests: UnsafePointer<CChar>?,
    _ rating: UnsafePointer<CChar>?,
    _ date: UnsafePointer<CChar>?,
    _ temp: UnsafePointer<CChar>?,
    _ weather: UnsafePointer<CChar>?
) {
    guard let sessionPtr else { return }
    let cashStr = cash.map { String(cString: $0) } ?? "—"
    let guestsStr = guests.map { String(cString: $0) } ?? "—"
    let ratingStr = rating.map { String(cString: $0) } ?? "—"
    let dateStr = date.map { String(cString: $0) } ?? "—"
    let tempStr = temp.map { String(cString: $0) } ?? "—"
    let weatherStr = weather.map { String(cString: $0) } ?? "—"
    MainActor.assumeIsolated {
        Unmanaged<MacParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().setStatus(
            cash: cashStr,
            guests: guestsStr,
            rating: ratingStr,
            date: dateStr,
            temp: tempStr,
            weather: weatherStr
        )
    }
}

@_cdecl("OpenRCT2MacChromeSetState")
func OpenRCT2MacChromeSetState(
    _ sessionPtr: UnsafeMutableRawPointer?,
    _ paused: Bool,
    _ muted: Bool,
    _ speed: UInt8
) {
    guard let sessionPtr else { return }
    MainActor.assumeIsolated {
        Unmanaged<MacParkChromeSession>.fromOpaque(sessionPtr)
            .takeUnretainedValue()
            .setState(paused: paused, muted: muted, speed: speed)
    }
}
