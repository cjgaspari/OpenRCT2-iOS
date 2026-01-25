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

    /// Default game resolution (matches X8DrawingEngine output)
    private static let DEFAULT_GAME_WIDTH: Int = 1280
    private static let DEFAULT_GAME_HEIGHT: Int = 720

    /// Plane size in meters (1 pixel = 0.001m for readable UI at typical viewing distance)
    /// Results in 1.28m × 0.72m plane for 16:9 aspect ratio
    private static let METERS_PER_PIXEL: Float = 0.001

    /// Minimum size thresholds to avoid unnecessary resize operations
    private static let MIN_SIZE_CHANGE: CGFloat = 10

    // MARK: - Dependencies

    /// The game engine providing rendering and game loop coordination
    private let gameEngine: GameEngine

    // MARK: - State

    /// Holds the plane entity for material and size updates
    @State private var planeEntity: ModelEntity?

    /// TextureResource created from DrawableQueue for dynamic updates
    @State private var textureResource: TextureResource?

    /// Current game dimensions for resize detection
    @State private var currentWidth: Int = DEFAULT_GAME_WIDTH
    @State private var currentHeight: Int = DEFAULT_GAME_HEIGHT

    // MARK: - Initialization

    /// Creates a GameView with the specified game engine
    /// - Parameter gameEngine: The GameEngine coordinating rendering and game logic
    init(gameEngine: GameEngine) {
        self.gameEngine = gameEngine
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
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
            .onChange(of: geometry.size) { oldSize, newSize in
                handleGeometryChange(newSize: newSize)
            }
        }
    }

    // MARK: - Window Resize Handling

    /// Handles window geometry changes and triggers game resize if needed
    /// - Parameter newSize: The new window size in points
    @MainActor
    private func handleGeometryChange(newSize: CGSize) {
        // Calculate game resolution from window size
        // Maintain 16:9 aspect ratio, scale to fit window
        let targetAspect: CGFloat = 16.0 / 9.0
        let windowAspect = newSize.width / newSize.height

        let gameWidth: Int
        let gameHeight: Int

        if windowAspect > targetAspect {
            // Window is wider than 16:9 - constrain by height
            gameHeight = max(360, Int(newSize.height))
            gameWidth = Int(CGFloat(gameHeight) * targetAspect)
        } else {
            // Window is narrower or equal - constrain by width
            gameWidth = max(640, Int(newSize.width))
            gameHeight = Int(CGFloat(gameWidth) / targetAspect)
        }

        // Avoid resize for small changes
        let widthChange = abs(gameWidth - currentWidth)
        let heightChange = abs(gameHeight - currentHeight)

        guard widthChange >= Int(Self.MIN_SIZE_CHANGE) || heightChange >= Int(Self.MIN_SIZE_CHANGE)
        else {
            return
        }

        // Perform resize
        if let newQueue = gameEngine.resize(width: gameWidth, height: gameHeight) {
            // Update plane entity with new dimensions and texture
            updatePlaneEntity(width: gameWidth, height: gameHeight, drawableQueue: newQueue)
            currentWidth = gameWidth
            currentHeight = gameHeight
        }
    }

    /// Updates the plane entity size and material for new game dimensions
    /// - Parameters:
    ///   - width: New game width in pixels
    ///   - height: New game height in pixels
    ///   - drawableQueue: New DrawableQueue for texture binding
    @MainActor
    private func updatePlaneEntity(
        width: Int, height: Int, drawableQueue: TextureResource.DrawableQueue
    ) {
        guard let entity = planeEntity else { return }

        // Calculate new plane dimensions in meters
        let planeWidth = Float(width) * Self.METERS_PER_PIXEL
        let planeHeight = Float(height) * Self.METERS_PER_PIXEL

        // Generate new mesh with updated dimensions
        let newMesh = MeshResource.generatePlane(width: planeWidth, height: planeHeight)

        do {
            // Try to update mesh
            try entity.model?.mesh.replace(with: newMesh.contents)
        } catch {
            // Fallback: create new model component
            print("Mesh replace failed, creating new model: \(error)")
            entity.model = ModelComponent(mesh: newMesh, materials: entity.model?.materials ?? [])
        }

        // Create new texture material with updated DrawableQueue
        if let newMaterial = createTextureMaterial(
            from: drawableQueue, width: width, height: height)
        {
            entity.model?.materials = [newMaterial]
        }

        // Update collision shapes for new size
        entity.generateCollisionShapes(recursive: false)
    }

    // MARK: - Entity Creation

    /// Creates a plane mesh entity for game display with texture material
    /// - Returns: ModelEntity with correctly sized plane mesh and texture material
    @MainActor
    private func createGamePlane() -> ModelEntity {
        // Get current dimensions from engine
        let (width, height) = gameEngine.getCurrentDimensions()
        currentWidth = width
        currentHeight = height

        let planeWidth = Float(width) * Self.METERS_PER_PIXEL
        let planeHeight = Float(height) * Self.METERS_PER_PIXEL

        // Generate plane mesh with game aspect ratio
        // Using width (x) and height (z) in RealityKit's coordinate system
        // The plane is created in the XZ plane, then positioned to face the user
        let mesh = MeshResource.generatePlane(
            width: planeWidth,
            height: planeHeight
        )

        // Create material with game texture from DrawableQueue
        let material = createInitialTextureMaterial()

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

    /// Creates an UnlitMaterial with the game texture from DrawableQueue (initial setup)
    /// - Returns: UnlitMaterial configured with game texture, or fallback gray material
    @MainActor
    private func createInitialTextureMaterial() -> UnlitMaterial {
        // Get DrawableQueue from game engine's renderer
        guard let drawableQueue = gameEngine.getDrawableQueue() else {
            // Fallback to placeholder if DrawableQueue not available
            return createFallbackMaterial()
        }

        return createTextureMaterial(
            from: drawableQueue, width: currentWidth, height: currentHeight)
            ?? createFallbackMaterial()
    }

    /// Creates an UnlitMaterial from a DrawableQueue
    /// - Parameters:
    ///   - drawableQueue: The DrawableQueue providing dynamic texture updates
    ///   - width: Texture width for placeholder image
    ///   - height: Texture height for placeholder image
    /// - Returns: UnlitMaterial configured with the texture, or nil on failure
    @MainActor
    private func createTextureMaterial(
        from drawableQueue: TextureResource.DrawableQueue, width: Int, height: Int
    ) -> UnlitMaterial? {
        do {
            // Create initial placeholder TextureResource from a solid color CGImage
            // This will be replaced by DrawableQueue content
            guard let placeholderImage = createPlaceholderImage(width: width, height: height) else {
                throw TextureCreationError.placeholderImageFailed
            }

            let options = TextureResource.CreateOptions(semantic: .color)
            let resource = try TextureResource.generate(
                from: placeholderImage,
                options: options
            )

            // Replace with DrawableQueue for dynamic texture updates
            // The DrawableQueue manages frame presentation internally
            // Note: replace(withDrawables:) modifies the resource's backing store
            resource.replace(withDrawables: drawableQueue)
            textureResource = resource

            // Create UnlitMaterial with the texture
            // UnlitMaterial is appropriate since the game handles its own lighting in 2D
            let material = UnlitMaterial(texture: resource)
            return material
        } catch {
            // If texture creation fails, log and return nil
            print("Failed to create TextureResource: \(error)")
            return nil
        }
    }

    /// Creates a fallback gray material for error cases
    /// - Returns: UnlitMaterial with gray tint
    private func createFallbackMaterial() -> UnlitMaterial {
        var fallbackMaterial = UnlitMaterial()
        fallbackMaterial.color = .init(tint: .gray)
        return fallbackMaterial
    }

    /// Creates a placeholder CGImage for initial texture
    /// - Parameters:
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    /// - Returns: CGImage with solid gray color, or nil if creation fails
    private func createPlaceholderImage(width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        // Create gray pixel data (BGRA format)
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[i] = 128  // Blue
            pixels[i + 1] = 128  // Green
            pixels[i + 2] = 128  // Red
            pixels[i + 3] = 255  // Alpha
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
        // Note: Preview may show gray fallback if engine init fails in preview context
        if let engine = try? GameEngine() {
            GameView(gameEngine: engine)
        } else {
            Text("Engine unavailable in preview")
        }
    }
#endif
