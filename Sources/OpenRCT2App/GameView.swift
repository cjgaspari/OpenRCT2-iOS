import MetalKit
// GameView.swift - SwiftUI wrapper for Metal view
import SwiftUI

struct GameView: View {
    var body: some View {
        MetalGameView()
            .background(Color.black)
    }
}

#if os(iOS)
    struct MetalGameView: UIViewRepresentable {
        func makeUIView(context: Context) -> MTKView {
            let metalView = MTKView()
            metalView.device = MTLCreateSystemDefaultDevice()
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            metalView.preferredFramesPerSecond = 60
            metalView.enableSetNeedsDisplay = false
            metalView.isPaused = false

            let renderer = GameRenderer(metalView: metalView)
            metalView.delegate = renderer
            context.coordinator.renderer = renderer

            return metalView
        }

        func updateUIView(_ uiView: MTKView, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator {
            var renderer: GameRenderer?
        }
    }
#else
    struct MetalGameView: NSViewRepresentable {
        func makeNSView(context: Context) -> MTKView {
            let metalView = MTKView()
            metalView.device = MTLCreateSystemDefaultDevice()
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            metalView.preferredFramesPerSecond = 60
            metalView.enableSetNeedsDisplay = false
            metalView.isPaused = false

            let renderer = GameRenderer(metalView: metalView)
            metalView.delegate = renderer
            context.coordinator.renderer = renderer

            return metalView
        }

        func updateNSView(_ nsView: MTKView, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator {
            var renderer: GameRenderer?
        }
    }
#endif

#Preview {
    GameView()
}
