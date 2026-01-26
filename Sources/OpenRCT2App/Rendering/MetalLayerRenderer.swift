import Metal
import QuartzCore

/// Metal renderer for CAMetalLayer presentation.
/// Converts indexed pixels + palette into a BGRA texture, then draws fullscreen.
final class MetalLayerRenderer {
    enum RendererError: Error {
        case deviceUnavailable
        case commandQueueUnavailable
        case libraryUnavailable
        case pipelineUnavailable
        case samplerUnavailable
        case computePipelineUnavailable
        case textureCreationFailed
        case paletteBufferUnavailable
    }

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let renderPipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let computePipelineState: MTLComputePipelineState

    private var indexedTexture: MTLTexture?
    private var outputTextures: [MTLTexture] = []
    private var outputIndex: Int = 0
    private var paletteBuffer: MTLBuffer?

    private var currentWidth: Int = 0
    private var currentHeight: Int = 0

    let useDoubleBuffering: Bool

    init(useDoubleBuffering: Bool = false) throws {
        self.useDoubleBuffering = useDoubleBuffering
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.deviceUnavailable
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueUnavailable
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.libraryUnavailable
        }

        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
            let fragmentFunction = library.makeFunction(name: "fragment_main")
        else {
            throw RendererError.pipelineUnavailable
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.samplerUnavailable
        }
        self.samplerState = samplerState

        guard let computeFunction = library.makeFunction(name: "convertIndexedTextureToRGBA") else {
            throw RendererError.computePipelineUnavailable
        }
        self.computePipelineState = try device.makeComputePipelineState(function: computeFunction)

        try ensurePaletteBuffer()
    }

    func updatePalette(_ palettePtr: UnsafeRawPointer, count: Int) throws {
        try ensurePaletteBuffer()
        guard let paletteBuffer = paletteBuffer else {
            throw RendererError.paletteBufferUnavailable
        }
        let byteCount = min(count * MemoryLayout<UInt32>.size, paletteBuffer.length)
        memcpy(paletteBuffer.contents(), palettePtr, byteCount)
    }

    func uploadFrame(
        framePtr: UnsafeRawPointer,
        width: Int,
        height: Int,
        strideBytes: Int
    ) throws {
        try ensureTextures(width: width, height: height)
        guard let indexedTexture = indexedTexture else {
            throw RendererError.textureCreationFailed
        }

        let bytesPerRow = max(strideBytes, width)
        if strideBytes < width {
            print("🧰 [MetalRenderer] warning: strideBytes (\(strideBytes)) < width (\(width))")
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        indexedTexture.replace(region: region, mipmapLevel: 0, withBytes: framePtr, bytesPerRow: bytesPerRow)
    }

    func draw(to layer: CAMetalLayer, viewport: MTLViewport) throws {
        guard let drawable = layer.nextDrawable() else {
            return
        }
        guard let outputTexture = currentOutputTexture, let indexedTexture = indexedTexture else {
            throw RendererError.textureCreationFailed
        }
        guard let paletteBuffer = paletteBuffer else {
            throw RendererError.paletteBufferUnavailable
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RendererError.commandQueueUnavailable
        }

        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipelineState)
            computeEncoder.setTexture(indexedTexture, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            computeEncoder.setBuffer(paletteBuffer, offset: 0, index: 0)

            let threadWidth = computePipelineState.threadExecutionWidth
            let threadHeight = max(1, computePipelineState.maxTotalThreadsPerThreadgroup / threadWidth)
            let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
            let groupWidth = (currentWidth + threadWidth - 1) / threadWidth
            let groupHeight = (currentHeight + threadHeight - 1) / threadHeight
            let threadgroups = MTLSize(width: groupWidth, height: groupHeight, depth: 1)
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setViewport(viewport)
            renderEncoder.setFragmentTexture(outputTexture, index: 0)
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
        advanceOutputIndex()
    }

    private func ensurePaletteBuffer() throws {
        if paletteBuffer != nil {
            return
        }
        let paletteSize = 256 * MemoryLayout<UInt32>.size
        paletteBuffer = device.makeBuffer(length: paletteSize, options: .storageModeShared)
        if paletteBuffer == nil {
            throw RendererError.paletteBufferUnavailable
        }
        print("🧰 [MetalRenderer] palette buffer allocated (\(paletteSize) bytes)")
    }

    private func ensureTextures(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            return
        }
        if width == currentWidth && height == currentHeight && indexedTexture != nil && !outputTextures.isEmpty {
            return
        }

        let indexedDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint,
            width: width,
            height: height,
            mipmapped: false
        )
        indexedDescriptor.usage = [.shaderRead]
        indexedDescriptor.storageMode = .shared

        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]
        outputDescriptor.storageMode = .shared

        guard let newIndexed = device.makeTexture(descriptor: indexedDescriptor) else {
            throw RendererError.textureCreationFailed
        }

        indexedTexture = newIndexed

        outputTextures = []
        let outputCount = useDoubleBuffering ? 2 : 1
        for _ in 0..<outputCount {
            guard let newOutput = device.makeTexture(descriptor: outputDescriptor) else {
                throw RendererError.textureCreationFailed
            }
            outputTextures.append(newOutput)
        }
        outputIndex = 0
        currentWidth = width
        currentHeight = height
        print("🧱 [MetalRenderer] textures allocated \(width)x\(height) (doubleBuffering=\(useDoubleBuffering))")
    }

    private var currentOutputTexture: MTLTexture? {
        guard !outputTextures.isEmpty else { return nil }
        return outputTextures[outputIndex % outputTextures.count]
    }

    private func advanceOutputIndex() {
        guard useDoubleBuffering, outputTextures.count > 1 else { return }
        outputIndex = (outputIndex + 1) % outputTextures.count
    }
}
