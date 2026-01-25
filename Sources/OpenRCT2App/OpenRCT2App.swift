// OpenRCT2App - visionOS entry point
import SwiftUI

@main
struct OpenRCT2App: App {
    /// Game engine managing the game loop and rendering
    @State private var gameEngine: GameEngine?

    /// Error message if initialization fails
    @State private var initError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let engine = gameEngine {
                    GameView(renderer: engine.renderer)
                        .ignoresSafeArea()
                } else if let error = initError {
                    // Show error if engine failed to initialize
                    VStack {
                        Text("Failed to initialize game")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Loading state while engine initializes
                    ProgressView("Initializing...")
                }
            }
            .task {
                await initializeGameEngine()
            }
        }
    }

    /// Initializes the GameEngine and starts the game loop
    @MainActor
    private func initializeGameEngine() async {
        do {
            let engine = try GameEngine()
            engine.start()  // Begin 40Hz game loop
            gameEngine = engine
        } catch {
            initError = error.localizedDescription
        }
    }
}
