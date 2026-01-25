import CoreGraphics
import RealityKit
import SwiftUI

/// Main game display view using RealityKit for visionOS
/// Renders the OpenRCT2 game on a plane entity with dynamic texture updates
@available(visionOS 1.0, *)
@available(macOS, unavailable)
@available(iOS, unavailable)
struct GameView: View {
    // MARK: - Constants

    /// Game resolution (matches X8DrawingEngine output)
    private static let GAME_WIDTH: Int = 1280
    private static let GAME_HEIGHT: Int = 720

    /// Plane size in meters (1 pixel = 0.001m for readable UI at typical viewing distance)
    /// Results in 1.28m × 0.72m plane for 16:9 aspect ratio
    private static let METERS_PER_PIXEL: Float = 0.001
    private static let PLANE_WIDTH: Float = Float(GAME_WIDTH) * METERS_PER_PIXEL  // 1.28m
    private static let PLANE_HEIGHT: Float = Float(GAME_HEIGHT) * METERS_PER_PIXEL  // 0.72m

    // MARK: - Dependencies

    /// The renderer providing the game texture via DrawableQueue
    private let renderer: OpenRCT2Renderer

    // MARK: - State

    /// Holds the plane entity for material updates
    @State private var planeEntity: ModelEntity?

    /// TextureResource created from DrawableQueue for dynamic updates
    @State private var textureResource: TextureResource?

    // MARK: - Initialization

    /// Creates a GameView with the specified renderer
    /// - Parameter renderer: The OpenRCT2Renderer providing the game texture
    init(renderer: OpenRCT2Renderer) {
        self.renderer = renderer
    }

    // MARK: - Body

    var body: some View {
        RealityView { content in
            // Create the game display plane with texture material
            let entity = createGamePlane()
            content.add(entity)
            planeEntity = entity
        } update: { content in
            // Update closure called when SwiftUI state changes
            // TextureResource updates automatically via DrawableQueue - no manual update needed
            // The DrawableQueue manages frame presentation internally
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entity Creation

    /// Creates a plane mesh entity for game display with texture material
    /// - Returns: ModelEntity with correctly sized plane mesh and texture material
    @MainActor
    private func createGamePlane() -> ModelEntity {
        // Generate plane mesh with game aspect ratio
        // Using width (x) and height (z) in RealityKit's coordinate system
        // The plane is created in the XZ plane, then positioned to face the user
        let mesh = MeshResource.generatePlane(
            width: Self.PLANE_WIDTH,
            height: Self.PLANE_HEIGHT
        )

        // Create material with game texture from DrawableQueue
        let material = createTextureMaterial()

        // Create model entity with mesh and material
        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Position plane to face user (RealityKit planes default to XZ, we need XY)
        // Rotate -90 degrees around X to make plane vertical (facing +Z toward user)
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))

        // Center the plane at origin (default window placement)
        entity.position = .zero

        // Add collision for future input handling (VOS-040+)
        entity.generateCollisionShapes(recursive: false)

        // Enable input targeting for gestures
        entity.components.set(InputTargetComponent())

        return entity
    }

    /// Creates an UnlitMaterial with the game texture from DrawableQueue
    /// - Returns: UnlitMaterial configured with game texture, or fallback gray material
    @MainActor
    private func createTextureMaterial() -> UnlitMaterial {
        // Get DrawableQueue from renderer
        guard let drawableQueue = renderer.getDrawableQueue() else {
            // Fallback to placeholder if DrawableQueue not available
            var fallbackMaterial = UnlitMaterial()
            fallbackMaterial.color = .init(tint: .gray)
            return fallbackMaterial
        }

        do {
            // Create initial placeholder TextureResource from a solid color CGImage
            // This will be replaced by DrawableQueue content
            guard let placeholderImage = createPlaceholderImage() else {
                throw TextureCreationError.placeholderImageFailed
            }

            let options = TextureResource.CreateOptions(semantic: .color)
            var resource = try TextureResource.generate(
                from: placeholderImage,
                options: options
            )

            // Replace with DrawableQueue for dynamic texture updates
            // The DrawableQueue manages frame presentation internally
            resource.replace(withDrawables: drawableQueue)
            textureResource = resource

            // Create UnlitMaterial with the texture
            // UnlitMaterial is appropriate since the game handles its own lighting in 2D
            let material = UnlitMaterial(texture: resource)
            return material
        } catch {
            // If texture creation fails, use fallback gray material
            print("Failed to create TextureResource: \(error)")
            var fallbackMaterial = UnlitMaterial()
            fallbackMaterial.color = .init(tint: .gray)
            return fallbackMaterial
        }
    }

    /// Creates a placeholder CGImage for initial texture
    /// - Returns: CGImage with solid gray color, or nil if creation fails
    private func createPlaceholderImage() -> CGImage? {
        let width = Self.GAME_WIDTH
        let height = Self.GAME_HEIGHT
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        // Create gray pixel data (BGRA format)
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[i] = 128     // Blue
            pixels[i + 1] = 128 // Green
            pixels[i + 2] = 128 // Red
            pixels[i + 3] = 255 // Alpha
        }

        // Create CGImage from pixel data
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixels,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        return context.makeImage()
    }
}

// MARK: - Errors

/// Errors that can occur during texture creation
private enum TextureCreationError: LocalizedError {
    case placeholderImageFailed

    var errorDescription: String? {
        switch self {
        case .placeholderImageFailed:
            return "Failed to create placeholder CGImage"
        }
    }
}

// MARK: - Preview

#if DEBUG && os(visionOS)
    @available(visionOS 1.0, *)
    #Preview {
        // Note: Preview may show gray fallback if renderer init fails in preview context
        if let renderer = try? OpenRCT2Renderer() {
            GameView(renderer: renderer)
        } else {
            Text("Renderer unavailable in preview")
        }
    }
#endif
