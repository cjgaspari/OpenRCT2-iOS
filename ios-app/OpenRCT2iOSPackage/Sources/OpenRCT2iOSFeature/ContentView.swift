import MetalKit
// ContentView.swift - SwiftUI wrapper for Metal game view
import SwiftUI

public struct ContentView: View {
    public var body: some View {
        MetalGameView()
            .background(Color.black)
            .ignoresSafeArea()
    }

    public init() {}
}

public struct MetalGameView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> MTKView {
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

    public func updateUIView(_ uiView: MTKView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public class Coordinator {
        var renderer: GameRenderer?
    }
}

#Preview {
    ContentView()
}
