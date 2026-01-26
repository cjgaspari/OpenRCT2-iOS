import SwiftUI

/// SwiftUI host for the CAMetalLayer renderer.
struct GameView: View {
    private static let defaultWidth: CGFloat = 1280
    private static let defaultHeight: CGFloat = 720
    private static let minWidth: CGFloat = 640
    private static let minHeight: CGFloat = 360

    @State private var framebufferSize = CGSize(
        width: defaultWidth,
        height: defaultHeight
    )
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            let targetSize = computeFramebufferSize(for: geometry.size)
            ZStack {
                MetalLayerViewRepresentable(
                    framebufferSize: targetSize,
                    errorMessage: $errorMessage
                )
                if let errorMessage {
                    ErrorOverlay(message: errorMessage)
                }
            }
            .onAppear {
                framebufferSize = targetSize
                log("[Size] initial framebuffer \(Int(targetSize.width))x\(Int(targetSize.height))")
            }
            .onChange(of: geometry.size) { _, newSize in
                let newFramebuffer = computeFramebufferSize(for: newSize)
                if newFramebuffer != framebufferSize {
                    framebufferSize = newFramebuffer
                    log("[Size] framebuffer \(Int(newFramebuffer.width))x\(Int(newFramebuffer.height))")
                }
            }
        }
    }

    private func computeFramebufferSize(for windowSize: CGSize) -> CGSize {
        guard windowSize.width > 0, windowSize.height > 0 else {
            return framebufferSize
        }

        let targetAspect = Self.defaultWidth / Self.defaultHeight
        let windowAspect = windowSize.width / windowSize.height

        let width: CGFloat
        let height: CGFloat

        if windowAspect > targetAspect {
            height = max(Self.minHeight, windowSize.height)
            width = height * targetAspect
        } else {
            width = max(Self.minWidth, windowSize.width)
            height = width / targetAspect
        }

        return CGSize(width: width.rounded(.down), height: height.rounded(.down))
    }

    private func log(_ message: String) {
        print("📐 [GameView] \(message)")
    }
}

struct MetalLayerViewRepresentable: UIViewRepresentable {
    let framebufferSize: CGSize
    @Binding var errorMessage: String?

    final class Coordinator {
        private let errorMessage: Binding<String?>

        init(errorMessage: Binding<String?>) {
            self.errorMessage = errorMessage
        }

        func reportError(_ message: String?) {
            DispatchQueue.main.async {
                self.errorMessage.wrappedValue = message
            }
        }
    }

    func makeUIView(context: Context) -> MetalLayerView {
        let view = MetalLayerView()
        view.onError = { [weak coordinator = context.coordinator] message in
            coordinator?.reportError(message)
        }
        return view
    }

    func updateUIView(_ uiView: MetalLayerView, context: Context) {
        uiView.updateFramebufferSize(width: Int(framebufferSize.width), height: Int(framebufferSize.height))
        uiView.startRendering()
        uiView.onError = { [weak coordinator = context.coordinator] message in
            coordinator?.reportError(message)
        }
    }

    static func dismantleUIView(_ uiView: MetalLayerView, coordinator: ()) {
        uiView.stopRendering()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(errorMessage: $errorMessage)
    }
}

private struct ErrorOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text("OpenRCT2 Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding()
    }
}
