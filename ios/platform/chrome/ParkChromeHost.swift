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
        registerForTraitChanges(
            [UITraitVerticalSizeClass.self, UITraitHorizontalSizeClass.self]
        ) { (host: Self, _) in
            host.view.invalidateIntrinsicContentSize()
        }
    }

    // Menu morph reports a compact preferred size; do not let that resize SDL.
    override var preferredContentSize: CGSize {
        get { CGSize(width: 1, height: 1) }
        set {}
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        if let canvas = sceneCanvasSize() {
            let matchesScene =
                abs(size.width - canvas.width) < 1 && abs(size.height - canvas.height) < 1
            if !matchesScene {
                return
            }
        }
        coordinator.animate { _ in
            self.view.invalidateIntrinsicContentSize()
        }
    }

    private func sceneCanvasSize() -> CGSize? {
        guard let scene = view.window?.windowScene else {
            return nil
        }
        return scene.effectiveGeometry.coordinateSpace.bounds.size
    }
}

private final class ScenarioPickerHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }
}

final class ParkChromeSession: NSObject {
    let model = ParkChromeModel()
    let scenarioModel = ScenarioPickerModel()
    private let onAction: @convention(c) (Int32, Int32) -> Void
    private var cameraHost: ParkChromeHostingController<BuildCluster>?
    private var statusHost: ParkChromeHostingController<StatusMenu>?
    private var pauseHost: ParkChromeHostingController<PauseSpeedMenu>?
    private var dockHost: ParkChromeHostingController<ParkChromeDockView>?
    private var scenarioHost: ScenarioPickerHostingController<ScenarioPickerRootView>?
    private var container: ParkChromePassThroughView?
    private var topConstraints: [NSLayoutConstraint] = []
    private var bottomConstraints: [NSLayoutConstraint] = []
    private var scenarioConstraints: [NSLayoutConstraint] = []

    init(onAction: @escaping @convention(c) (Int32, Int32) -> Void) {
        self.onAction = onAction
        super.init()
        model.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
        scenarioModel.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
        model.onSwapBottomControlsChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.applyBottomLayout()
            }
        }
        scenarioModel.onPresentationChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.applyVisibility()
                self?.bringToFront()
            }
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
        let statusHost = ParkChromeHostingController(rootView: StatusMenu(model: model))
        let pauseHost = ParkChromeHostingController(rootView: PauseSpeedMenu(model: model))
        let cameraHost = ParkChromeHostingController(rootView: BuildCluster(model: model))
        let dockHost = ParkChromeHostingController(rootView: ParkChromeDockView(model: model))
        let scenarioHost = ScenarioPickerHostingController(rootView: ScenarioPickerRootView(model: scenarioModel))
        install(statusHost, in: container, parent: parentController)
        install(pauseHost, in: container, parent: parentController)
        install(cameraHost, in: container, parent: parentController)
        install(dockHost, in: container, parent: parentController)
        install(scenarioHost, in: container, parent: parentController)

        scenarioConstraints = [
            scenarioHost.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scenarioHost.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scenarioHost.view.topAnchor.constraint(equalTo: container.topAnchor),
            scenarioHost.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]
        NSLayoutConstraint.activate(scenarioConstraints)

        self.statusHost = statusHost
        self.pauseHost = pauseHost
        self.cameraHost = cameraHost
        self.dockHost = dockHost
        self.scenarioHost = scenarioHost
        self.container = container
        applyTopLayout()
        applyBottomLayout()
        applyVisibility()
        bringToFront()
    }

    func detach() {
        NSLayoutConstraint.deactivate(topConstraints)
        NSLayoutConstraint.deactivate(bottomConstraints)
        NSLayoutConstraint.deactivate(scenarioConstraints)
        topConstraints = []
        bottomConstraints = []
        scenarioConstraints = []
        detachHost(statusHost)
        detachHost(pauseHost)
        detachHost(cameraHost)
        detachHost(dockHost)
        detachHost(scenarioHost)
        container?.removeFromSuperview()
        statusHost = nil
        pauseHost = nil
        cameraHost = nil
        dockHost = nil
        scenarioHost = nil
        container = nil
    }

    func setParkOpen(_ open: Bool) {
        if !open {
            model.isShowingBuildTools = false
            model.isShowingViewTools = false
        }
        model.isParkOpen = open
        applyVisibility()
        if open {
            bringToFront()
        }
    }

    func setState(paused: Bool, speed: UInt8, flags: UInt32) {
        if model.isPaused != paused {
            model.isPaused = paused
        }
        if model.speed != speed {
            model.speed = speed
        }
        if model.viewportFlags != flags {
            model.viewportFlags = flags
        }
    }

    func setStatus(cash: String, guests: String, rating: String, date: String) {
        model.cash = cash
        model.guests = guests
        model.rating = rating
        model.date = date
    }

    func presentScenarioPicker(snapshotJSON: String) {
        scenarioModel.present(snapshotJSON: snapshotJSON)
        applyVisibility()
        bringToFront()
    }

    func dismissScenarioPicker() {
        scenarioModel.dismissFromEngine()
        applyVisibility()
    }

    func setScenarioPreviewLoading(scenarioID: Int32, loading: Bool) {
        scenarioModel.setPreviewLoading(scenarioID: scenarioID, loading: loading)
    }

    func setScenarioPreview(
        scenarioID: Int32,
        rgba: UnsafePointer<UInt8>?,
        width: Int32,
        height: Int32
    ) {
        scenarioModel.setPreview(scenarioID: scenarioID, rgba: rgba, width: width, height: height)
    }

    func bringToFront() {
        guard let container else {
            return
        }
        container.superview?.bringSubviewToFront(container)
    }

    private func applyTopLayout() {
        guard let status = statusHost?.view, let pause = pauseHost?.view, let container else {
            return
        }

        NSLayoutConstraint.deactivate(topConstraints)
        // The horizontally corner-adapted margins avoid the iPad window
        // controls while preserving the usual system spacing on iPhone.
        let content = container.layoutGuide(for: .margins(cornerAdaptation: .horizontal))
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pause.setContentCompressionResistancePriority(.required, for: .horizontal)
        pause.setContentHuggingPriority(.required, for: .horizontal)
        topConstraints = [
            status.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            pause.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            pause.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            pause.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: pause.leadingAnchor, constant: -12),
        ]
        NSLayoutConstraint.activate(topConstraints)
    }

    private func applyBottomLayout() {
        guard let camera = cameraHost?.view, let dock = dockHost?.view, let container else {
            return
        }

        NSLayoutConstraint.deactivate(bottomConstraints)
        let content = container.layoutGuide(for: .margins(cornerAdaptation: .horizontal))
        if model.swapBottomControls {
            bottomConstraints = [
                camera.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                camera.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
                dock.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                dock.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
                camera.trailingAnchor.constraint(lessThanOrEqualTo: dock.leadingAnchor, constant: -12),
            ]
        } else {
            bottomConstraints = [
                dock.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                dock.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
                camera.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                camera.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
                dock.trailingAnchor.constraint(lessThanOrEqualTo: camera.leadingAnchor, constant: -12),
            ]
        }
        NSLayoutConstraint.activate(bottomConstraints)
    }

    private func applyVisibility() {
        let parkHidden = !model.isParkOpen
        statusHost?.view.isHidden = parkHidden
        pauseHost?.view.isHidden = parkHidden
        cameraHost?.view.isHidden = parkHidden
        dockHost?.view.isHidden = parkHidden
        scenarioHost?.view.isHidden = !scenarioModel.isPresented

        let visible = model.isParkOpen || scenarioModel.isPresented
        container?.isHidden = !visible
        container?.isUserInteractionEnabled = visible
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
