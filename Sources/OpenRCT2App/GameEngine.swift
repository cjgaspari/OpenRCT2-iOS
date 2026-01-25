import Foundation
import RealityKit

/// C interop bindings for OpenRCT2
@_silgen_name("openrct2_set_paths")
func openrct2_set_paths(
    _ bundlePath: UnsafePointer<CChar>?, _ userPath: UnsafePointer<CChar>?,
    _ cachePath: UnsafePointer<CChar>?)

@_silgen_name("openrct2_init")
func openrct2_init(_ configPath: UnsafeRawPointer?) -> Bool

@_silgen_name("openrct2_init_full")
func openrct2_init_full() -> Bool

@_silgen_name("openrct2_get_init_error")
func openrct2_get_init_error() -> UnsafePointer<CChar>?

@_silgen_name("openrct2_shutdown")
func openrct2_shutdown()

@_silgen_name("openrct2_tick")
func openrct2_tick()

@_silgen_name("openrct2_get_frame_buffer")
func openrct2_get_frame_buffer() -> UnsafeRawPointer?

@_silgen_name("openrct2_get_palette")
func openrct2_get_palette() -> UnsafeRawPointer?

@_silgen_name("openrct2_get_pitch")
func openrct2_get_pitch() -> Int32

@_silgen_name("openrct2_set_screen_size")
func openrct2_set_screen_size(_ width: Int32, _ height: Int32) -> Bool

@_silgen_name("openrct2_get_frame_width")
func openrct2_get_frame_width() -> UInt32

@_silgen_name("openrct2_get_frame_height")
func openrct2_get_frame_height() -> UInt32

/// Manages OpenRCT2 game engine integration with Swift
/// Coordinates game ticks, frame rendering, and palette updates
final class GameEngine: @unchecked Sendable {
    private static let DEFAULT_WIDTH = 1280
    private static let DEFAULT_HEIGHT = 720

    let renderer: OpenRCT2Renderer

    private var isRunning = false
    private let engineQueue = DispatchQueue(label: "com.openrct2.engine", qos: .userInteractive)

    /// Current screen dimensions (thread-safe access via engineQueue)
    private var screenWidth: Int
    private var screenHeight: Int

    /// Lock for coordinating resize operations
    private let resizeLock = NSLock()

    // MARK: - Initialization

    /// Creates and initializes the game engine
    /// - Throws: If renderer creation fails
    init() throws {
        self.renderer = try OpenRCT2Renderer()
        self.screenWidth = Self.DEFAULT_WIDTH
        self.screenHeight = Self.DEFAULT_HEIGHT

        // Set paths from Swift bundle info before initializing OpenRCT2
        let bundleResourcePath = Bundle.main.bundlePath + "/visionos-resources"
        let documentsPath =
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let cachePath =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""

        print("GameEngine: Setting paths:")
        print("  bundleResourcePath: \(bundleResourcePath)")
        print("  documentsPath: \(documentsPath)")
        print("  cachePath: \(cachePath)")

        bundleResourcePath.withCString { bundleCStr in
            documentsPath.withCString { userCStr in
                cachePath.withCString { cacheCStr in
                    openrct2_set_paths(bundleCStr, userCStr, cacheCStr)
                }
            }
        }

        // Initialize OpenRCT2 core
        let initialized = openrct2_init(nil)
        guard initialized else {
            let errorMsg = getInitError() ?? "Unknown error"
            print("GameEngine: openrct2_init() failed: \(errorMsg)")
            throw GameEngineError.initializationFailed
        }
        print("GameEngine: openrct2_init() succeeded")

        // Complete full initialization (loads assets, drawing engine)
        let fullyInitialized = openrct2_init_full()
        if !fullyInitialized {
            let errorMsg = getInitError() ?? "Unknown error"
            print("GameEngine: openrct2_init_full() failed: \(errorMsg)")
            // Continue anyway - standalone mode will work
            print("GameEngine: Continuing in standalone test pattern mode")
        } else {
            print("GameEngine: openrct2_init_full() succeeded - full game mode active")
        }

        // Warm-up: Force first tick to create the X8DrawingEngine
        // This ensures pixel buffer is available before game loop starts
        openrct2_tick()
        print("GameEngine: First tick completed, pixel buffer should be ready")
    }

    /// Helper to get initialization error from C++
    private func getInitError() -> String? {
        guard let cStr = openrct2_get_init_error() else { return nil }
        return String(cString: cStr)
    }

    deinit {
        stop()
        openrct2_shutdown()
    }

    // MARK: - Game Loop

    /// Starts background game loop at ~40 Hz
    /// Game ticks are independent from display refresh (90/120 Hz)
    func start() {
        guard !isRunning else { return }
        isRunning = true

        engineQueue.async { [weak self] in
            self?.gameLoopCycle()
        }
    }

    /// Stops the game loop
    func stop() {
        isRunning = false
    }

    /// Main game loop cycle
    /// Runs ticks and render at ~40 Hz
    private func gameLoopCycle() {
        let tickInterval: TimeInterval = 0.025  // 40 Hz
        var lastTick = Date()

        while isRunning {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastTick)

            if elapsed >= tickInterval {
                // Advance game state
                openrct2_tick()

                // Update palette and frame
                updatePalette()
                do {
                    try uploadFrame()
                } catch {
                    print("Frame upload failed: \(error)")
                }

                lastTick = now
            } else {
                // Sleep to avoid busy-waiting
                let sleepDuration = tickInterval - elapsed
                Thread.sleep(forTimeInterval: sleepDuration * 0.9)  // Sleep 90% to reduce jitter
            }
        }
    }

    // MARK: - Rendering

    /// Updates palette on GPU if it has changed
    /// Called each tick before frame upload
    private func updatePalette() {
        guard let palettePtr = openrct2_get_palette() else { return }

        // Palette is 256 entries × 4 bytes (BGRA)
        renderer.updatePalette(palettePtr, count: 256)
    }

    /// Uploads current game frame to drawable queue
    /// Copies indexed pixels, dispatches compute shader, presents result
    private func uploadFrame() throws {
        guard let framePtr = openrct2_get_frame_buffer() else {
            throw GameEngineError.frameBufferUnavailable
        }

        let pitch = openrct2_get_pitch()

        // Use thread-safe dimensions
        resizeLock.lock()
        let width = screenWidth
        let height = screenHeight
        resizeLock.unlock()

        try renderer.uploadFrame(
            indexedPixels: framePtr,
            width: width,
            height: height,
            pitch: Int(pitch)
        )
    }

    /// Gets the drawable queue for RealityKit dynamic texture updates
    /// - Returns: DrawableQueue for material binding
    func getDrawableQueue() -> TextureResource.DrawableQueue? {
        return renderer.getDrawableQueue()
    }

    /// Resizes the game screen to new dimensions
    /// This coordinates resizing across the C++ engine, Swift renderer, and SwiftUI
    /// - Parameters:
    ///   - width: New width in pixels
    ///   - height: New height in pixels
    /// - Returns: The new DrawableQueue if resize succeeded, nil otherwise
    func resize(width: Int, height: Int) -> TextureResource.DrawableQueue? {
        guard width > 0 && height > 0 else { return nil }

        // Skip if dimensions unchanged
        resizeLock.lock()
        let unchanged = (width == screenWidth && height == screenHeight)
        resizeLock.unlock()

        if unchanged {
            return renderer.getDrawableQueue()
        }

        // Notify C++ side of new dimensions
        let cppResized = openrct2_set_screen_size(Int32(width), Int32(height))
        guard cppResized else {
            print("GameEngine: C++ resize failed for \(width)x\(height)")
            return nil
        }

        // Resize the renderer (recreates DrawableQueue)
        do {
            let newQueue = try renderer.resize(width: width, height: height)

            // Update tracked dimensions
            resizeLock.lock()
            screenWidth = width
            screenHeight = height
            resizeLock.unlock()

            print("GameEngine: Resized to \(width)x\(height)")
            return newQueue
        } catch {
            print("GameEngine: Renderer resize failed: \(error)")
            return nil
        }
    }

    /// Returns current game dimensions
    /// - Returns: Tuple of (width, height) in pixels
    func getCurrentDimensions() -> (width: Int, height: Int) {
        resizeLock.lock()
        defer { resizeLock.unlock() }
        return (screenWidth, screenHeight)
    }
}

// MARK: - Error Handling

enum GameEngineError: LocalizedError {
    case initializationFailed
    case frameBufferUnavailable
    case renderingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize OpenRCT2 engine"
        case .frameBufferUnavailable:
            return "Frame buffer not available"
        case .renderingFailed(let error):
            return "Rendering failed: \(error)"
        }
    }
}
