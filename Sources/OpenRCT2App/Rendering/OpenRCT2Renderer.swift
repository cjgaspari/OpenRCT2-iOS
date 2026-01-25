import Foundation
import Metal
import MetalKit
import RealityKit

/// Manages Metal texture pipeline via RealityKit's DrawableQueue
/// Converts indexed 8-bit game pixels to BGRA for display
final class OpenRCT2Renderer {
    /// Game resolution
    private static let DEFAULT_WIDTH = 1280
    private static let DEFAULT_HEIGHT = 720
    
    // MARK: - Metal Resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    // MARK: - DrawableQueue & Texture
    private var drawableQueue: TextureResource.DrawableQueue?
    
    // MARK: - Compute Pipeline
    private var computePipelineState: MTLComputePipelineState?
    
    // MARK: - Buffers
    private var indexedBuffer: MTLBuffer?
    private var paletteBuffer: MTLBuffer?
    
    // MARK: - Dimensions
    private(set) var width: Int
    private(set) var height: Int
    private var pitch: Int  // May differ from width due to alignment
    
    // MARK: - Initialization
    
    /// Creates a new OpenRCT2Renderer with Metal device and command queue
    /// - Throws: If Metal device creation fails
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.deviceCreationFailed
        }
        
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }
        
        self.commandQueue = commandQueue
        
        // Initialize dimensions first
        self.width = OpenRCT2Renderer.DEFAULT_WIDTH
        self.height = OpenRCT2Renderer.DEFAULT_HEIGHT
        self.pitch = OpenRCT2Renderer.DEFAULT_WIDTH
        
        // Initialize DrawableQueue at default resolution
        try initializeDrawableQueue(width: OpenRCT2Renderer.DEFAULT_WIDTH, height: OpenRCT2Renderer.DEFAULT_HEIGHT)
        
        // Initialize Metal buffers
        try initializeBuffers()
        
        // Compile compute shader
        try initializeComputeShader()
    }
    
    // MARK: - Setup
    
    /// Initializes the DrawableQueue at specified resolution
    /// - Parameters:
    ///   - width: Texture width in pixels
    ///   - height: Texture height in pixels
    /// - Throws: If DrawableQueue creation fails
    private func initializeDrawableQueue(width: Int, height: Int) throws {
        // Create DrawableQueue descriptor
        let descriptor = TextureResource.DrawableQueue.Descriptor(
            pixelFormat: .bgra8Unorm,  // BGRA format for direct Metal compatibility
            width: width,
            height: height,
            usage: [.shaderWrite],     // Compute shader writes to this texture
            mipmapsMode: .none         // No mipmapping needed for game UI
        )
        
        // Create the DrawableQueue
        self.drawableQueue = try TextureResource.DrawableQueue(descriptor)
        
        self.width = width
        self.height = height
        self.pitch = width  // Assume no extra stride for now; update if X8DrawingEngine differs
    }
    
    /// Initializes Metal buffers for indexed pixels and palette data
    /// - Throws: If buffer creation fails
    private func initializeBuffers() throws {
        // Indexed pixel buffer (8-bit per pixel)
        let pixelBufferSize = width * height
        guard let indexedBuf = device.makeBuffer(length: pixelBufferSize, options: .storageModeShared) else {
            throw RendererError.bufferCreationFailed
        }
        indexedBuffer = indexedBuf
        
        // Palette buffer (256 × 4 bytes BGRA)
        let paletteSize = 256 * MemoryLayout<UInt32>.size
        guard let paletteBuf = device.makeBuffer(length: paletteSize, options: .storageModeShared) else {
            throw RendererError.bufferCreationFailed
        }
        paletteBuffer = paletteBuf
    }
    
    /// Loads and compiles the compute shader pipeline
    /// - Throws: If shader compilation fails
    private func initializeComputeShader() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.shaderCompilationFailed
        }
        
        guard let function = library.makeFunction(name: "convertIndexedToRGBA") else {
            throw RendererError.shaderFunctionNotFound
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            throw RendererError.pipelineStateCreationFailed(error)
        }
    }
    
    // MARK: - Public API
    
    /// Returns the DrawableQueue for use in RealityKit materials
    /// The queue manages the texture resource dynamically
    /// - Returns: DrawableQueue if initialized, nil otherwise
    func getDrawableQueue() -> TextureResource.DrawableQueue? {
        return drawableQueue
    }
    
    /// Updates the palette data on the GPU
    /// - Parameter palette: Pointer to BGRA palette data (256 × 4 bytes)
    /// - Parameter count: Number of palette entries (should be 256)
    func updatePalette(_ palette: UnsafeRawPointer, count: Int) {
        guard let paletteBuf = paletteBuffer else { return }
        
        let bytesToCopy = min(count * MemoryLayout<UInt32>.size, paletteBuf.length)
        memcpy(paletteBuf.contents(), palette, bytesToCopy)
    }
    
    /// Uploads a frame from the game engine to the DrawableQueue texture
    /// Copies indexed pixels, dispatches compute shader, and presents the result
    /// - Parameters:
    ///   - indexedPixels: Pointer to 8-bit indexed color buffer
    ///   - width: Frame width (must match initialized width)
    ///   - height: Frame height (must match initialized height)
    ///   - pitch: Bytes per row (stride) in pixel buffer
    /// - Throws: If drawable retrieval or command submission fails
    func uploadFrame(indexedPixels: UnsafeRawPointer, width: Int, height: Int, pitch: Int) throws {
        guard let queue = drawableQueue else {
            throw RendererError.drawableQueueNotInitialized
        }
        
        // Validate dimensions
        guard width == self.width && height == self.height else {
            throw RendererError.dimensionMismatch
        }
        
        // Copy indexed pixels to GPU buffer
        copyIndexedPixels(indexedPixels, pitch: pitch)
        
        // Get next drawable from queue (blocks if necessary)
        let drawable = try queue.nextDrawable()
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RendererError.commandBufferCreationFailed
        }
        
        // Get Metal texture from drawable
        let metalTexture = drawable.texture
        
        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RendererError.computeEncoderCreationFailed
        }
        
        // Dispatch compute shader
        try dispatchComputeShader(
            encoder: computeEncoder,
            texture: metalTexture,
            width: width,
            height: height
        )
        
        computeEncoder.endEncoding()
        
        // Present and commit
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    /// Resizes the rendering surface
    /// Recreates DrawableQueue and buffers at new dimensions
    /// - Parameters:
    ///   - width: New width in pixels
    ///   - height: New height in pixels
    /// - Throws: If DrawableQueue recreation fails
    func resize(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw RendererError.invalidDimensions
        }
        
        // Reinitialize DrawableQueue
        try initializeDrawableQueue(width: width, height: height)
        
        // Reallocate buffers
        try initializeBuffers()
    }
    
    // MARK: - Private Helpers
    
    /// Copies indexed pixel data from game buffer to Metal buffer
    /// Handles pitch/stride differences
    /// - Parameters:
    ///   - source: Pointer to indexed pixel data from X8DrawingEngine
    ///   - pitch: Stride (bytes per row) in source buffer
    private func copyIndexedPixels(_ source: UnsafeRawPointer, pitch: Int) {
        guard let indexedBuf = indexedBuffer else { return }
        
        let dest = indexedBuf.contents()
        
        // If pitch matches width, copy in one operation
        if pitch == width {
            memcpy(dest, source, width * height)
        } else {
            // Copy row by row, skipping padding
            let sourceBytes = source.assumingMemoryBound(to: UInt8.self)
            let destBytes = dest.assumingMemoryBound(to: UInt8.self)
            
            for row in 0 ..< height {
                let srcOffset = row * pitch
                let dstOffset = row * width
                memcpy(
                    destBytes + dstOffset,
                    sourceBytes + srcOffset,
                    width
                )
            }
        }
    }
    
    /// Dispatches the palette conversion compute shader
    /// - Parameters:
    ///   - encoder: Metal compute command encoder
    ///   - texture: Output Metal texture (from drawable)
    ///   - width: Texture width
    ///   - height: Texture height
    /// - Throws: If compute shader dispatch fails
    private func dispatchComputeShader(
        encoder: MTLComputeCommandEncoder,
        texture: MTLTexture,
        width: Int,
        height: Int
    ) throws {
        guard let pipelineState = computePipelineState else {
            throw RendererError.computePipelineNotInitialized
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(indexedBuffer, offset: 0, index: 0)
        encoder.setBuffer(paletteBuffer, offset: 0, index: 1)
        encoder.setTexture(texture, index: 0)
        
        // Calculate threadgroup size (typical: 16×16 or 8×8)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroupCount = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
    }
}

// MARK: - Error Handling

enum RendererError: LocalizedError {
    case deviceCreationFailed
    case commandQueueCreationFailed
    case bufferCreationFailed
    case shaderCompilationFailed
    case shaderFunctionNotFound
    case pipelineStateCreationFailed(Error)
    case drawableQueueNotInitialized
    case dimensionMismatch
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case computePipelineNotInitialized
    case invalidDimensions
    
    var errorDescription: String? {
        switch self {
        case .deviceCreationFailed:
            return "Failed to create Metal device"
        case .commandQueueCreationFailed:
            return "Failed to create command queue"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .shaderCompilationFailed:
            return "Failed to compile Metal shader library"
        case .shaderFunctionNotFound:
            return "Shader function 'convertIndexedToRGBA' not found"
        case .pipelineStateCreationFailed(let error):
            return "Failed to create compute pipeline state: \(error)"
        case .drawableQueueNotInitialized:
            return "DrawableQueue not initialized"
        case .dimensionMismatch:
            return "Frame dimensions don't match initialized texture dimensions"
        case .commandBufferCreationFailed:
            return "Failed to create command buffer"
        case .computeEncoderCreationFailed:
            return "Failed to create compute command encoder"
        case .computePipelineNotInitialized:
            return "Compute pipeline state not initialized"
        case .invalidDimensions:
            return "Invalid dimensions (must be > 0)"
        }
    }
}
