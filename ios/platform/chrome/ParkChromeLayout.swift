/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI
import UIKit

extension ParkChromeSession {
    func applyTopLayout() {
        guard let status = statusHost?.view,
              let pause = pauseHost?.view,
              let container else {
            return
        }

        NSLayoutConstraint.deactivate(topConstraints)
        // Use the scene-local safe area for asymmetric vertical bars and add
        // horizontal corner adaptation for rounded displays. The design inset
        // keeps Liquid Glass's visual bloom away from the physical edge.
        let content = container.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pause.setContentCompressionResistancePriority(.required, for: .horizontal)
        pause.setContentHuggingPriority(.required, for: .horizontal)
        let duoRightChromeActive = usesDuoRightChrome
        if model.isDuoRightChromeActive != duoRightChromeActive {
            model.isDuoRightChromeActive = duoRightChromeActive
        }
        if duoRightChromeActive {
            topConstraints = [
                status.leadingAnchor.constraint(
                    equalTo: content.leadingAnchor,
                    constant: ParkChromeLayout.edgeInset),
                status.bottomAnchor.constraint(
                    equalTo: content.bottomAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                status.trailingAnchor.constraint(
                    lessThanOrEqualTo: content.trailingAnchor,
                    constant: -ParkChromeLayout.edgeInset),
            ]
        } else {
            topConstraints = [
                status.topAnchor.constraint(
                    equalTo: content.topAnchor,
                    constant: ParkChromeLayout.edgeInset),
                status.leadingAnchor.constraint(
                    equalTo: content.leadingAnchor,
                    constant: ParkChromeLayout.edgeInset),
                pause.topAnchor.constraint(
                    equalTo: content.topAnchor,
                    constant: ParkChromeLayout.edgeInset),
                pause.trailingAnchor.constraint(
                    equalTo: content.trailingAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                pause.centerYAnchor.constraint(equalTo: status.centerYAnchor),
                status.trailingAnchor.constraint(
                    lessThanOrEqualTo: pause.leadingAnchor,
                    constant: -ParkChromeLayout.controlSpacing),
            ]
        }
        NSLayoutConstraint.activate(topConstraints)
    }

    func applyBottomLayout() {
        guard let pause = pauseHost?.view,
              let camera = cameraHost?.view,
              let dock = dockHost?.view,
              let container else {
            return
        }

        NSLayoutConstraint.deactivate(bottomConstraints)
        let content = container.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))
        if usesDuoRightChrome {
            // This is deliberately app-owned chrome. SDL remains the window's
            // root controller, while the controls occupy the scene's trailing
            // safe-area strip without changing UIKit containment.
            let trailingInset = max(container.safeAreaInsets.right, 64)
            let railCenterOffset = trailingInset / 2
            let statusReserve: CGFloat
            if #available(iOS 27.1, *) {
                statusReserve = container.trailingControlRailTop
            } else {
                statusReserve = container.safeAreaInsets.top + ParkChromeLayout.edgeInset
            }
            let bottomInset = max(container.safeAreaInsets.bottom, ParkChromeLayout.edgeInset)
            bottomConstraints = [
                pause.centerXAnchor.constraint(
                    equalTo: container.safeAreaLayoutGuide.trailingAnchor,
                    constant: railCenterOffset),
                pause.topAnchor.constraint(
                    equalTo: container.topAnchor,
                    constant: statusReserve),
                dock.centerXAnchor.constraint(equalTo: pause.centerXAnchor),
                dock.bottomAnchor.constraint(
                    equalTo: container.bottomAnchor,
                    constant: -bottomInset),
                camera.centerXAnchor.constraint(equalTo: pause.centerXAnchor),
                camera.bottomAnchor.constraint(
                    equalTo: dock.topAnchor,
                    constant: -24),
            ]
        } else if model.swapBottomControls {
            bottomConstraints = [
                camera.leadingAnchor.constraint(
                    equalTo: content.leadingAnchor,
                    constant: ParkChromeLayout.edgeInset),
                camera.bottomAnchor.constraint(
                    equalTo: content.bottomAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                dock.trailingAnchor.constraint(
                    equalTo: content.trailingAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                dock.bottomAnchor.constraint(
                    equalTo: content.bottomAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                camera.trailingAnchor.constraint(
                    lessThanOrEqualTo: dock.leadingAnchor,
                    constant: -ParkChromeLayout.controlSpacing),
            ]
        } else {
            bottomConstraints = [
                dock.leadingAnchor.constraint(
                    equalTo: content.leadingAnchor,
                    constant: ParkChromeLayout.edgeInset),
                dock.bottomAnchor.constraint(
                    equalTo: content.bottomAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                camera.trailingAnchor.constraint(
                    equalTo: content.trailingAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                camera.bottomAnchor.constraint(
                    equalTo: content.bottomAnchor,
                    constant: -ParkChromeLayout.edgeInset),
                dock.trailingAnchor.constraint(
                    lessThanOrEqualTo: camera.leadingAnchor,
                    constant: -ParkChromeLayout.controlSpacing),
            ]
        }
        NSLayoutConstraint.activate(bottomConstraints)
    }

    private var usesDuoRightChrome: Bool {
        guard model.usesDuoRightChrome else {
            return false
        }
        if #available(iOS 27.1, *) {
            return container?.traitCollection.verticalBarEdge == .trailing
        }
        return false
    }

    func applyVisibility() {
        let parkHidden = !model.isParkOpen
        statusHost?.view.isHidden = parkHidden
        pauseHost?.view.isHidden = parkHidden
        cameraHost?.view.isHidden = parkHidden
        dockHost?.view.isHidden = parkHidden
        scenarioHost?.view.isHidden = !scenarioModel.isPresented
        loadSaveHost?.view.isHidden = !loadSaveModel.isPresented
        let visible = model.isParkOpen || scenarioModel.isPresented || loadSaveModel.isPresented
        container?.isHidden = !visible
        container?.isUserInteractionEnabled = visible
    }

    /// Returns constraints that pin `view` to all four edges of `container`.
    /// Used by both the scenario picker and load/save overlay.
    func makeFullScreenConstraints(for view: UIView, in container: UIView) -> [NSLayoutConstraint] {
        [
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]
    }

    func install(_ host: UIViewController, in container: UIView, parent: UIViewController?) {
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

    func detachHost(_ host: UIViewController?) {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
    }
}
