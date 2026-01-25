// OpenRCT2App - visionOS entry point
import SwiftUI

@main
struct OpenRCT2App: App {
    /// Shared renderer instance for game texture management
    @State private var renderer: OpenRCT2Renderer?

    /// Error message if renderer initialization fails
    @State private var rendererError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let renderer = renderer {
                    GameView(renderer: renderer)
                        .ignoresSafeArea()
                } else if let error = rendererError {
                    // Show error if renderer failed to initialize
                    VStack {
                        Text("Failed to initialize renderer")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Loading state while renderer initializes
                    ProgressView("Initializing...")
                }
            }
            .task {
                await initializeRenderer()
            }
        }
    }

    /// Initializes the OpenRCT2Renderer on the main actor
    @MainActor
    private func initializeRenderer() async {
        do {
            renderer = try OpenRCT2Renderer()
        } catch {
            rendererError = error.localizedDescription
        }
    }
}
