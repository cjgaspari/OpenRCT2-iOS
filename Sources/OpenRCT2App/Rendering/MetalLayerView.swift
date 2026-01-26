import Foundation
import QuartzCore

#if canImport(UIKit)
import UIKit

/// CAMetalLayer-backed view that drives OpenRCT2 tick + render.
@available(visionOS 1.0, *)
final class MetalLayerView: UIView {
    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }

    private var renderer: MetalLayerRenderer?
    private var displayLink: CADisplayLink?
    private var tickOwnerActive = false
    private var engineInitialized = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stopDisplayLink()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
        } else {
            startDisplayLink()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer.frame = bounds
        let scale = contentScaleFactor
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    private func commonInit() {
        do {
            renderer = try MetalLayerRenderer()
        } catch {
            print("MetalLayerRenderer init failed: \(error)")
            return
        }

        metalLayer.device = renderer?.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        let scale = traitCollection.displayScale
        metalLayer.contentsScale = scale
        contentScaleFactor = scale
        isOpaque = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        guard OpenRCT2TickCoordinator.shared.acquire(.displayLink) else {
            print("MetalLayerView: tick loop already owned by another driver.")
            return
        }
        tickOwnerActive = true
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        if tickOwnerActive {
            OpenRCT2TickCoordinator.shared.release(.displayLink)
            tickOwnerActive = false
        }
    }

    @objc private func appWillResignActive() {
        displayLink?.isPaused = true
    }

    @objc private func appDidBecomeActive() {
        displayLink?.isPaused = false
    }

    @objc private func step() {
        guard let renderer = renderer else { return }
        guard ensureEngineInitialized() else {
            stopDisplayLink()
            return
        }

        openrct2_tick()

        guard let framePtr = openrct2_get_frame_buffer() else { return }
        let width = Int(openrct2_get_frame_width())
        let height = Int(openrct2_get_frame_height())
        let stride = Int(openrct2_get_pitch())

        if let palettePtr = openrct2_get_palette() {
            try? renderer.updatePalette(palettePtr, count: 256)
        }

        do {
            try renderer.uploadFrame(
                framePtr: framePtr,
                width: width,
                height: height,
                strideBytes: stride
            )
            try renderer.draw(to: metalLayer)
        } catch {
            print("MetalLayerView render error: \(error)")
        }
    }

    private func ensureEngineInitialized() -> Bool {
        if engineInitialized {
            return true
        }

        let bundleResourcePath = Bundle.main.bundlePath + "/visionos-resources"
        let documentsPath =
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let cachePath =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""

        bundleResourcePath.withCString { bundleCStr in
            documentsPath.withCString { userCStr in
                cachePath.withCString { cacheCStr in
                    openrct2_set_paths(bundleCStr, userCStr, cacheCStr)
                }
            }
        }

        guard openrct2_init(nil) else {
            let error = openrct2_get_init_error().map { String(cString: $0) } ?? "Unknown error"
            print("openrct2_init failed: \(error)")
            return false
        }

        if !openrct2_init_full() {
            let error = openrct2_get_init_error().map { String(cString: $0) } ?? "Unknown error"
            print("openrct2_init_full failed: \(error)")
        }

        engineInitialized = true
        return true
    }
}
#endif
