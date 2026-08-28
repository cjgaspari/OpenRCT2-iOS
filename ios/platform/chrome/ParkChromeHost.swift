/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI
import UIKit

final class ParkChromePassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event), hit !== self else {
            return nil
        }
        // iOS 26 glass buttons are SwiftUI controls: hit-testing lands on the
        // hosting view itself, not a UIButton. Returning nil here made every
        // chrome tap fall through to the park (pan worked, buttons did not).
        return hit
    }
}

private final class ParkChromeHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        sizingOptions = [.intrinsicContentSize]
        safeAreaRegions = []
    }
}

final class ParkChromeSession: NSObject {
    let model = ParkChromeModel()
    private let onAction: @convention(c) (Int32, Int32) -> Void
    private var cameraHost: ParkChromeHostingController<BuildCluster>?
    private var topHost: ParkChromeHostingController<UnitedTopBar>?
    private var dockHost: ParkChromeHostingController<ParkChromeDockView>?
    private var container: ParkChromePassThroughView?
    private var bottomConstraints: [NSLayoutConstraint] = []

    init(onAction: @escaping @convention(c) (Int32, Int32) -> Void) {
        self.onAction = onAction
        super.init()
        model.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
    }

    func attach(to parent: UIView) {
        detach()

        let container = ParkChromePassThroughView(frame: parent.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = .clear
        container.isOpaque = false
        container.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            container.topAnchor.constraint(equalTo: parent.topAnchor),
            container.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])

        let parentController = parent.owningViewController
        let topHost = ParkChromeHostingController(rootView: UnitedTopBar(model: model))
        let cameraHost = ParkChromeHostingController(rootView: BuildCluster(model: model))
        let dockHost = ParkChromeHostingController(rootView: ParkChromeDockView(model: model))
        install(topHost, in: container, parent: parentController)
        install(cameraHost, in: container, parent: parentController)
        install(dockHost, in: container, parent: parentController)

        let topView = topHost.view!
        let safe = container.safeAreaLayoutGuide
        topView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            topView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            topView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            topView.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),
        ])

        self.topHost = topHost
        self.cameraHost = cameraHost
        self.dockHost = dockHost
        self.container = container
        applyBottomLayout()
        applyParkOpen()
        bringToFront()
    }

    func detach() {
        NSLayoutConstraint.deactivate(bottomConstraints)
        bottomConstraints = []
        detachHost(topHost)
        detachHost(cameraHost)
        detachHost(dockHost)
        container?.removeFromSuperview()
        topHost = nil
        cameraHost = nil
        dockHost = nil
        container = nil
    }

    func setParkOpen(_ open: Bool) {
        if !open {
            model.isShowingBuildTools = false
            model.isShowingViewTools = false
        }
        model.isParkOpen = open
        applyParkOpen()
        if open {
            bringToFront()
        }
    }

    func setState(paused: Bool, speed: UInt8, flags: UInt32) {
        model.isPaused = paused
        model.speed = speed
        model.viewportFlags = flags
    }

    func setStatus(cash: String, guests: String, rating: String, date: String) {
        model.cash = cash
        model.guests = guests
        model.rating = rating
        model.date = date
    }

    func bringToFront() {
        guard let container else {
            return
        }
        container.superview?.bringSubviewToFront(container)
    }

    private func applyBottomLayout() {
        guard let camera = cameraHost?.view, let dock = dockHost?.view, let container else {
            return
        }

        NSLayoutConstraint.deactivate(bottomConstraints)
        let safe = container.safeAreaLayoutGuide
        bottomConstraints = [
            dock.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            dock.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            camera.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            camera.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            dock.trailingAnchor.constraint(lessThanOrEqualTo: camera.leadingAnchor, constant: -12),
        ]
        NSLayoutConstraint.activate(bottomConstraints)
    }

    private func applyParkOpen() {
        container?.isHidden = !model.isParkOpen
        container?.isUserInteractionEnabled = model.isParkOpen
    }

    private func install(_ host: UIViewController, in container: UIView, parent: UIViewController?) {
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        if let parent {
            parent.addChild(host)
        }
        container.addSubview(host.view)
        if let parent {
            host.didMove(toParent: parent)
        }
    }

    private func detachHost(_ host: UIViewController?) {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
    }
}

private extension UIView {
    var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return window?.rootViewController
    }
}

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

@_cdecl("OpenRCT2TouchChromeBringToFront")
func OpenRCT2TouchChromeBringToFront(_ sessionPtr: UnsafeMutableRawPointer?) {
    guard let sessionPtr else {
        return
    }
    Unmanaged<ParkChromeSession>.fromOpaque(sessionPtr).takeUnretainedValue().bringToFront()
}
