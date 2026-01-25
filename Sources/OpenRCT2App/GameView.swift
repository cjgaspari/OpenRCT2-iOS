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
    private static let GAME_WIDTH: Float = 1280
    private static let GAME_HEIGHT: Float = 720

    /// Plane size in meters (1 pixel = 0.001m for readable UI at typical viewing distance)
    /// Results in 1.28m × 0.72m plane for 16:9 aspect ratio
    private static let METERS_PER_PIXEL: Float = 0.001
    private static let PLANE_WIDTH: Float = GAME_WIDTH * METERS_PER_PIXEL  // 1.28m
    private static let PLANE_HEIGHT: Float = GAME_HEIGHT * METERS_PER_PIXEL  // 0.72m

    // MARK: - State

    /// Holds the plane entity for updates
    @State private var planeEntity: ModelEntity?

    // MARK: - Body

    var body: some View {
        RealityView { content in
            // Create the game display plane
            let entity = createGamePlane()
            content.add(entity)
            planeEntity = entity
        } update: { content in
            // Update closure called when SwiftUI state changes
            // Future: Apply texture material updates here (VOS-031)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entity Creation

    /// Creates a plane mesh entity for game display
    /// - Returns: ModelEntity with correctly sized plane mesh
    private func createGamePlane() -> ModelEntity {
        // Generate plane mesh with game aspect ratio
        // Using width (x) and height (z) in RealityKit's coordinate system
        // The plane is created in the XZ plane, then positioned to face the user
        let mesh = MeshResource.generatePlane(
            width: Self.PLANE_WIDTH,
            height: Self.PLANE_HEIGHT
        )

        // Create placeholder material (will be replaced in VOS-031 with TextureResource)
        // Using simple unlit material to avoid lighting artifacts on 2D game content
        var material = UnlitMaterial()
        material.color = .init(tint: .gray)  // Placeholder gray until texture is applied

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
}

// MARK: - Preview

#if DEBUG && os(visionOS)
    #Preview {
        GameView()
    }
#endif
