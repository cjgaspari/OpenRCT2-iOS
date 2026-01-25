import Foundation
import RealityKit

/// C interop bindings for OpenRCT2
@_silgen_name("openrct2_init")
func openrct2_init(_ configPath: UnsafeRawPointer?) -> Bool

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

/// Manages OpenRCT2 game engine integration with Swift
/// Coordinates game ticks, frame rendering, and palette updates
final class GameEngine: @unchecked Sendable {
    private static let SCREEN_WIDTH = 1280
    private static let SCREEN_HEIGHT = 720
    
    let renderer: OpenRCT2Renderer
    
    private var isRunning = false
    private let engineQueue = DispatchQueue(label: "com.openrct2.engine", qos: .userInteractive)
    
    // MARK: - Initialization
    
    /// Creates and initializes the game engine
    /// - Throws: If renderer creation fails
    init() throws {
        self.renderer = try OpenRCT2Renderer()
        
        // Initialize OpenRCT2 core
        let initialized = openrct2_init(nil)
        guard initialized else {
            throw GameEngineError.initializationFailed
        }
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
        
        try renderer.uploadFrame(
            indexedPixels: framePtr,
            width: Self.SCREEN_WIDTH,
            height: Self.SCREEN_HEIGHT,
            pitch: Int(pitch)
        )
    }
    
    /// Gets the drawable queue for RealityKit dynamic texture updates
    /// - Returns: DrawableQueue for material binding
    func getDrawableQueue() -> TextureResource.DrawableQueue? {
        return renderer.getDrawableQueue()
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
