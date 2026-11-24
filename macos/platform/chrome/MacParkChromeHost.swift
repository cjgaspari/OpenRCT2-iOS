/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import AppKit
import SwiftUI

/// Pass-through container: empty chrome regions leave mouse/keyboard to SDL.
final class MacChromePassThroughView: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
final class MacParkChromeSession: NSObject {
    private let model: MacParkChromeModel
    private var overlayView: MacChromePassThroughView?
    private var hostingView: NSHostingView<MacParkChromeOverlay>?
    private var parentView: NSView?

    init(onAction: @escaping (Int32, Int32) -> Void) {
        self.model = MacParkChromeModel(onAction: onAction)
        super.init()
    }

    func attach(to parent: NSView) {
        detach()
        parentView = parent

        let overlay = MacChromePassThroughView(frame: parent.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor

        let root = MacParkChromeOverlay(model: model)
        let host = NSHostingView(rootView: root)
        host.frame = overlay.bounds
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        overlay.addSubview(host)
        parent.addSubview(overlay, positioned: .above, relativeTo: nil)

        overlayView = overlay
        hostingView = host
        bringToFront()

        // First-class macOS menu bar (File/Edit/View/Window/Help). In-game
        // toolbar NSMenus stay unchanged — same action codes/indices.
        MacMenuBar.ensureInstalled { [model] code, extra in
            if let widx = MacToolbarWIDX(rawValue: code) {
                model.queue(widx, extra: extra)
            } else {
                model.forwardMenuCode(code, extra: extra)
            }
        }
    }

    func detach() {
        hostingView?.removeFromSuperview()
        overlayView?.removeFromSuperview()
        hostingView = nil
        overlayView = nil
        parentView = nil
    }

    func bringToFront() {
        guard let overlayView, let parentView else { return }
        parentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
        overlayView.frame = parentView.bounds
        hostingView?.frame = overlayView.bounds
    }

    func setIconDirectory(_ path: String) {
        MacToolbarIconStore.iconDirectory = URL(fileURLWithPath: path, isDirectory: true)
    }

    func setCleanedSpriteDirectory(_ path: String) {
        MacToolbarIconStore.cleanedSpriteDirectory = URL(fileURLWithPath: path, isDirectory: true)
    }

    func setVersion(_ version: String) {
        model.setVersion(version)
    }

    func setStatus(
        cash: String,
        guests: String,
        rating: String,
        date: String,
        temp: String,
        weather: String
    ) {
        model.statusCash = cash
        model.statusGuests = guests
        model.statusRating = rating
        model.statusDate = date
        model.statusTemp = temp
        model.statusWeather = weather
    }

    func setState(paused: Bool, muted: Bool, speed: UInt8) {
        model.isPaused = paused
        model.isMuted = muted
        model.speed = speed
    }

    func setParkChromeVisible(_ visible: Bool) {
        model.showParkChrome = visible
    }

    func setTitleChromeVisible(_ visible: Bool) {
        model.showTitleChrome = visible
    }

    func setNewsToast(message: String, showSubject: Bool, showLocate: Bool) {
        model.setNewsToast(message: message, showSubject: showSubject, showLocate: showLocate)
    }

    func setErrorToast(message: String) {
        model.setErrorToast(message: message)
    }
}
