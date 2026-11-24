/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI
import UIKit

enum ParkChromeLayout {
    static let edgeInset: CGFloat = 12
    static let controlSpacing: CGFloat = 12
}

final class ParkChromePassThroughView: UIView {
    var onLayoutEnvironmentChanged: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        if #available(iOS 27.1, *) {
            registerForTraitChanges(
                UITraitCollection.systemTraitsAffectingVerticalBarEdge
            ) { (view: ParkChromePassThroughView, _) in
                view.onLayoutEnvironmentChanged?()
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onLayoutEnvironmentChanged?()
    }

    @available(iOS 27.1, *)
    var trailingControlRailTop: CGFloat {
        let railLeading = bounds.maxX - safeAreaInsets.right
        var occupiedBottom = safeAreaInsets.top

        if let window,
           let statusBarFrame = window.windowScene?.statusBarManager?.statusBarFrame {
            let localStatusBarFrame = convert(statusBarFrame, from: window)
            if localStatusBarFrame.maxX > railLeading {
                occupiedBottom = max(occupiedBottom, localStatusBarFrame.maxY)
            }
        }

        for region in reservedRegions(kind: .occlusion, options: [])
        where region.isActive && region.frame.maxX > railLeading {
            occupiedBottom = max(occupiedBottom, region.frame.maxY)
        }

        return occupiedBottom + ParkChromeLayout.controlSpacing
    }

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

final class ParkChromeHostingController<Content: View>: UIHostingController<Content> {
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

/// Shared hosting controller for full-screen modal overlays (scenario picker,
/// load/save). Keeps the background transparent and defers safe-area handling
/// to the hosted SwiftUI view.
final class ModalHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }
}

