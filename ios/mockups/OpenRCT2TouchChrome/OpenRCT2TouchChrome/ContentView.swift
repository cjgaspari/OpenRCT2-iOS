import SwiftUI

struct ContentView: View {
    @State private var model = ChromePreviewModel()

    var body: some View {
        ZStack {
            ParkCanvas()
            chrome
        }
        .overlay(alignment: .center) {
            mockupSwitcher
        }
        .overlay(alignment: .center) {
            if let openWindow = model.openWindow {
                EngineWindowCard(title: openWindow.title, onClose: model.dismissWindowButtonTapped)
                    .padding(.horizontal, 80)
                    .offset(y: 72)
            }
        }
    }

    @ViewBuilder
    private var chrome: some View {
        switch model.mockup {
        case .floatingCluster:
            MockupA_FloatingCluster(model: model)
        case .trailingRail:
            MockupB_TrailingRail(model: model)
        case .morphingFAB:
            MockupC_MorphingFAB(model: model)
        case .findMySheet:
            MockupD_FindMySheet(model: model)
        }
    }

    private var mockupSwitcher: some View {
        Menu {
            ForEach(ChromeMockup.allCases) { mockup in
                Button(mockup.subtitle) {
                    mockupSelected(mockup)
                }
            }
        } label: {
            Label(model.mockup.subtitle, systemImage: "rectangle.on.rectangle.angled")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Choose chrome mockup")
    }

    private func mockupSelected(_ mockup: ChromeMockup) {
        model.mockupSelected(mockup)
    }
}

#Preview("Cluster") {
    ContentView()
}
