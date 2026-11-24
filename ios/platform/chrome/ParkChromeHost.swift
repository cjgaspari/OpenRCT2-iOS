/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI
import UIKit

final class ParkChromeSession: NSObject {
    let model = ParkChromeModel()
    let scenarioModel = ScenarioPickerModel()
    let loadSaveModel = LoadSaveModel()
    private let onAction: @convention(c) (Int32, Int32) -> Void
    // Layout/hosting state is internal so ParkChromeLayout.swift can own layout.
    var cameraHost: ParkChromeHostingController<BuildCluster>?
    var statusHost: ParkChromeHostingController<ParkChromeStatusView>?
    var pauseHost: ParkChromeHostingController<PauseSpeedMenu>?
    var dockHost: ParkChromeHostingController<ParkChromeDockView>?
    var scenarioHost: ModalHostingController<ScenarioPickerRootView>?
    var loadSaveHost: ModalHostingController<LoadSaveRootView>?
    var container: ParkChromePassThroughView?
    var topConstraints: [NSLayoutConstraint] = []
    var bottomConstraints: [NSLayoutConstraint] = []
    var modalConstraints: [NSLayoutConstraint] = []

    init(onAction: @escaping @convention(c) (Int32, Int32) -> Void) {
        self.onAction = onAction
        super.init()
        model.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
        scenarioModel.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
        model.onChromeLayoutChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.applyTopLayout()
                self?.applyBottomLayout()
                self?.applyVisibility()
            }
        }
        scenarioModel.onPresentationChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.applyVisibility()
                self?.bringToFront()
            }
        }
        loadSaveModel.onAction = { [weak self] code, extra in
            self?.onAction(code, extra)
        }
        loadSaveModel.onPresentationChanged = { [weak self] in
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
        let statusHost = ParkChromeHostingController(rootView: ParkChromeStatusView(model: model))
        let pauseHost = ParkChromeHostingController(rootView: PauseSpeedMenu(model: model))
        let cameraHost = ParkChromeHostingController(rootView: BuildCluster(model: model))
        let dockHost = ParkChromeHostingController(rootView: ParkChromeDockView(model: model))
        let scenarioHost = ModalHostingController(rootView: ScenarioPickerRootView(model: scenarioModel))
        let loadSaveHost = ModalHostingController(rootView: LoadSaveRootView(model: loadSaveModel))
        install(statusHost, in: container, parent: parentController)
        install(pauseHost, in: container, parent: parentController)
        install(cameraHost, in: container, parent: parentController)
        install(dockHost, in: container, parent: parentController)
        install(scenarioHost, in: container, parent: parentController)
        install(loadSaveHost, in: container, parent: parentController)

        modalConstraints =
            makeFullScreenConstraints(for: scenarioHost.view, in: container)
            + makeFullScreenConstraints(for: loadSaveHost.view, in: container)
        NSLayoutConstraint.activate(modalConstraints)

        self.statusHost = statusHost
        self.pauseHost = pauseHost
        self.cameraHost = cameraHost
        self.dockHost = dockHost
        self.scenarioHost = scenarioHost
        self.loadSaveHost = loadSaveHost
        self.container = container
        container.onLayoutEnvironmentChanged = { [weak self] in
            self?.applyTopLayout()
            self?.applyBottomLayout()
            self?.applyVisibility()
        }
        applyTopLayout()
        applyBottomLayout()
        applyVisibility()
        bringToFront()
    }

    func detach() {
        NSLayoutConstraint.deactivate(topConstraints)
        NSLayoutConstraint.deactivate(bottomConstraints)
        NSLayoutConstraint.deactivate(modalConstraints)
        topConstraints = []
        bottomConstraints = []
        modalConstraints = []
        detachHost(statusHost)
        detachHost(pauseHost)
        detachHost(cameraHost)
        detachHost(dockHost)
        detachHost(scenarioHost)
        detachHost(loadSaveHost)
        container?.removeFromSuperview()
        statusHost = nil
        pauseHost = nil
        cameraHost = nil
        dockHost = nil
        scenarioHost = nil
        loadSaveHost = nil
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

    func presentLoadSave(snapshotJSON: String) {
        loadSaveModel.present(snapshotJSON: snapshotJSON)
        applyVisibility()
        bringToFront()
    }

    func dismissLoadSave() {
        loadSaveModel.dismissFromEngine()
        applyVisibility()
    }

    // Copies the SwiftUI model's pending save name into a C buffer for the
    // engine to read while it handles the queued save action.
    func copyPendingSaveName(into buffer: UnsafeMutablePointer<CChar>?, length: Int32) -> Bool {
        guard let buffer, length > 0 else {
            return false
        }
        return loadSaveModel.saveName.withCString { source -> Bool in
            let capacity = Int(length) - 1
            let count = min(strlen(source), capacity)
            if count > 0 {
                memcpy(buffer, source, count)
            }
            buffer[count] = 0
            return true
        }
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

