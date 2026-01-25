// GameRenderer.swift - Metal renderer that displays OpenRCT2 frame buffer
import MetalKit
import OpenRCT2Core

final class GameRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var gameTexture: MTLTexture?
    private var rgbaBuffer: [UInt8]

    private let gameWidth = Int(ORCT2_SCREEN_WIDTH)
    private let gameHeight = Int(ORCT2_SCREEN_HEIGHT)

    init?(metalView: MTKView) {
        guard let device = metalView.device,
            let commandQueue = device.makeCommandQueue()
        else {
            print("Failed to create Metal device or command queue")
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.rgbaBuffer = [UInt8](repeating: 0, count: gameWidth * gameHeight * 4)

        // Create pipeline state
        guard let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "vertexShader"),
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
        else {
            print("Failed to create shader functions")
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }

        // Create texture for game frame buffer
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: gameWidth,
            height: gameHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("Failed to create game texture")
            return nil
        }
        self.gameTexture = texture

        super.init()

        // Initialize OpenRCT2
        if !openrct2_init(nil) {
            print("Warning: OpenRCT2 initialization returned false")
        }
    }

    deinit {
        openrct2_shutdown()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }

    func draw(in view: MTKView) {
        // Update game state
        openrct2_tick()

        // Get frame buffer and palette from C
        guard let frameBuffer = openrct2_get_frame_buffer(),
            let palette = openrct2_get_palette()
        else {
            return
        }

        // Convert 8-bit paletted to RGBA
        convertPalettedToRGBA(frameBuffer: frameBuffer, palette: palette)

        // Upload to texture
        gameTexture?.replace(
            region: MTLRegionMake2D(0, 0, gameWidth, gameHeight),
            mipmapLevel: 0,
            withBytes: rgbaBuffer,
            bytesPerRow: gameWidth * 4
        )

        // Render
        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(gameTexture, index: 0)

        // Draw fullscreen quad (6 vertices for 2 triangles)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func convertPalettedToRGBA(
        frameBuffer: UnsafePointer<UInt8>, palette: UnsafePointer<UInt8>
    ) {
        let pixelCount = gameWidth * gameHeight

        for i in 0..<pixelCount {
            let colorIndex = Int(frameBuffer[i])
            let paletteOffset = colorIndex * 3

            rgbaBuffer[i * 4 + 0] = palette[paletteOffset + 0]  // R
            rgbaBuffer[i * 4 + 1] = palette[paletteOffset + 1]  // G
            rgbaBuffer[i * 4 + 2] = palette[paletteOffset + 2]  // B
            rgbaBuffer[i * 4 + 3] = 255  // A
        }
    }
}
