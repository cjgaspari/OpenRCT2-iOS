import Foundation
import Metal
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
    private var currentFramebufferSize = CGSize.zero
    private var pendingFramebufferSize: CGSize?
    private var lastError: String?
#if DEBUG
    private var lastErrorLogTime: CFTimeInterval = 0
    private var lastFrameBufferLog: CFTimeInterval = 0
    private var lastPaletteLog: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFrameTimestamp: CFTimeInterval = CACurrentMediaTime()
#endif

    var onError: ((String?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stopRendering()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopRendering()
        } else {
            startRendering()
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
            emitError("Metal renderer init failed: \(error)")
            return
        }

        metalLayer.device = renderer?.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        let scale = traitCollection.displayScale
        metalLayer.contentsScale = scale
        contentScaleFactor = scale
        isOpaque = true
        log("[Init] CAMetalLayer configured (scale=\(scale))")

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

    func startRendering() {
        guard displayLink == nil else { return }
        guard OpenRCT2TickCoordinator.shared.acquire(.displayLink) else {
            log("[Tick] displayLink start blocked (owner already active)")
            return
        }
        tickOwnerActive = true
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
        log("[Tick] displayLink started")
    }

    func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
        if tickOwnerActive {
            OpenRCT2TickCoordinator.shared.release(.displayLink)
            tickOwnerActive = false
        }
        log("[Tick] displayLink stopped")
    }

    @objc private func appWillResignActive() {
        displayLink?.isPaused = true
        log("[App] will resign active; displayLink paused")
    }

    @objc private func appDidBecomeActive() {
        displayLink?.isPaused = false
        log("[App] became active; displayLink resumed")
    }

    @objc private func step() {
        guard let renderer = renderer else { return }
        guard ensureEngineInitialized() else {
            stopRendering()
            return
        }

        // Display link drives tick cadence; OpenRCT2 handles internal pacing.
        openrct2_tick()

        guard let framePtr = openrct2_get_frame_buffer() else {
#if DEBUG
            let now = CACurrentMediaTime()
            if now - lastFrameBufferLog > 1.0 {
                log("[Frame] frame buffer unavailable")
                lastFrameBufferLog = now
            }
#endif
            return
        }
        let width = Int(openrct2_get_frame_width())
        let height = Int(openrct2_get_frame_height())
        let stride = Int(openrct2_get_pitch())

        if let palettePtr = openrct2_get_palette() {
            try? renderer.updatePalette(palettePtr, count: 256)
        } else {
#if DEBUG
            let now = CACurrentMediaTime()
            if now - lastPaletteLog > 2.0 {
                log("[Frame] palette unavailable")
                lastPaletteLog = now
            }
#endif
        }

        let viewport = computeViewport(
            drawableSize: metalLayer.drawableSize,
            framebufferWidth: width,
            framebufferHeight: height
        )

        do {
            try renderer.uploadFrame(
                framePtr: framePtr,
                width: width,
                height: height,
                strideBytes: stride
            )
            try renderer.draw(to: metalLayer, viewport: viewport)
        } catch {
            emitError("Render error: \(error)")
        }

#if DEBUG
        frameCount += 1
        if frameCount >= 120 {
            let now = CACurrentMediaTime()
            let elapsed = now - lastFrameTimestamp
            if elapsed > 0 {
                let fps = Double(frameCount) / elapsed
                print(String(format: "MetalLayerView FPS: %.1f", fps))
            }
            lastFrameTimestamp = now
            frameCount = 0
        }
#endif
    }

    func updateFramebufferSize(width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        let newSize = CGSize(width: width, height: height)
        guard newSize != currentFramebufferSize else { return }

        currentFramebufferSize = newSize
        log("[Resize] framebuffer set to \(width)x\(height)")

        if engineInitialized {
            if !openrct2_set_screen_size(Int32(width), Int32(height)) {
                log("[Resize] openrct2_set_screen_size failed for \(width)x\(height)")
            }
        } else {
            pendingFramebufferSize = newSize
        }
    }

    private func ensureEngineInitialized() -> Bool {
        if engineInitialized {
            return true
        }

        log("[Init] starting OpenRCT2 bootstrap")
        let bundleResourcePath = Bundle.main.bundlePath + "/visionos-resources"
        let documentsPath =
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let cachePath =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""

        log("[Init] bundlePath=\(bundleResourcePath)")
        log("[Init] userPath=\(documentsPath)")
        log("[Init] cachePath=\(cachePath)")

        bundleResourcePath.withCString { bundleCStr in
            documentsPath.withCString { userCStr in
                cachePath.withCString { cacheCStr in
                    openrct2_set_paths(bundleCStr, userCStr, cacheCStr)
                }
            }
        }

        guard openrct2_init(nil) else {
            let error = openrct2_get_init_error().map { String(cString: $0) } ?? "Unknown error"
            emitError("openrct2_init failed: \(error)")
            return false
        }
        log("[Init] openrct2_init succeeded")

        if !openrct2_init_full() {
            let error = openrct2_get_init_error().map { String(cString: $0) } ?? "Unknown error"
            emitError("openrct2_init_full failed: \(error). Check g2.dat in visionos-resources.")
        } else {
            log("[Init] openrct2_init_full succeeded")
            clearError()
        }

        if let pendingSize = pendingFramebufferSize {
            let width = Int32(pendingSize.width)
            let height = Int32(pendingSize.height)
            _ = openrct2_set_screen_size(width, height)
            pendingFramebufferSize = nil
            log("[Resize] applied pending size \(Int(width))x\(Int(height))")
        }

        engineInitialized = true
        return true
    }

    private func computeViewport(
        drawableSize: CGSize,
        framebufferWidth: Int,
        framebufferHeight: Int
    ) -> MTLViewport {
        let drawableWidth = drawableSize.width
        let drawableHeight = drawableSize.height

        guard framebufferWidth > 0, framebufferHeight > 0 else {
            log("[Viewport] framebuffer size invalid; using drawable size")
            return MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(drawableWidth),
                height: Double(drawableHeight),
                znear: 0,
                zfar: 1
            )
        }

        let scaleX = drawableWidth / CGFloat(framebufferWidth)
        let scaleY = drawableHeight / CGFloat(framebufferHeight)
        let scale = min(scaleX, scaleY)

        let viewportWidth = CGFloat(framebufferWidth) * scale
        let viewportHeight = CGFloat(framebufferHeight) * scale
        let originX = (drawableWidth - viewportWidth) * 0.5
        let originY = (drawableHeight - viewportHeight) * 0.5

        return MTLViewport(
            originX: Double(originX),
            originY: Double(originY),
            width: Double(viewportWidth),
            height: Double(viewportHeight),
            znear: 0,
            zfar: 1
        )
    }

    private func log(_ message: String) {
        print("🧭 [MetalView] \(message)")
    }

    private func emitError(_ message: String) {
        if lastError != message {
            lastError = message
            onError?(message)
        }
#if DEBUG
        let now = CACurrentMediaTime()
        if now - lastErrorLogTime > 1.0 {
            print("🧭 [MetalView] [Error] \(message)")
            lastErrorLogTime = now
        }
#else
        print("🧭 [MetalView] [Error] \(message)")
#endif
    }

    private func clearError() {
        guard lastError != nil else { return }
        lastError = nil
        onError?(nil)
    }
}
#endif
