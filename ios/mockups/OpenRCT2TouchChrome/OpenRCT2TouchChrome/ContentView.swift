import SwiftUI

struct ContentView: View {
    @State private var model = ChromePreviewModel()
    @State private var showScenarioPicker = ProcessInfo.processInfo.arguments.contains("--scenario-picker")

    var body: some View {
        ZStack {
            ParkCanvas()
                .ignoresSafeArea()
            ParkChromePlayground(model: model)
        }
        .overlay(alignment: .top) {
            ChromeMixer(model: model)
                .padding(.top, 78)
        }
        .overlay(alignment: .bottom) {
            Button {
                showScenarioPicker = true
            } label: {
                Label("Open Scenario Picker", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .padding(.bottom, 120)
            .accessibilityIdentifier("openrct2.touch.mockup.openScenarioPicker")
        }
        .overlay(alignment: .center) {
            if let openWindow = model.openWindow {
                EngineWindowCard(title: openWindow.title, onClose: model.dismissWindowButtonTapped)
                    .padding(.horizontal, 48)
                    .offset(y: 128)
            }
        }
        .sheet(isPresented: $showScenarioPicker) {
            ScenarioPickerMockup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .presentationSizing(.page)
        }
        .task {
            await runStatusTicker()
        }
    }

    private func runStatusTicker() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(800))
            model.tickStatus()
        }
    }
}

struct ParkChromePlayground: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        VStack {
            TopChromeHost(model: model)
            Spacer()
            BottomChromeHost(model: model)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Always-visible mixers so Top A/B/C and Bottom A/B/C can be paired independently.
struct ChromeMixer: View {
    @Bindable var model: ChromePreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chrome mixer")
                .font(.caption.weight(.semibold))
            Picker("Top", selection: $model.top) {
                ForEach(TopChromeKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Top bar mockup")

            Picker("Bottom", selection: $model.bottom) {
                ForEach(BottomChromeKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Bottom bar mockup")

            Toggle("Left-handed controls", isOn: $model.leftHandedControls)
                .font(.caption)

            Text(model.top.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(model.bottom.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: 340)
        .glassEffect(in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chrome mixer")
    }
}

#Preview("Mixer") {
    ContentView()
}

#Preview("Union × Split") {
    PreviewChrome(top: .united, bottom: .split)
}

#Preview("HUD × Bar") {
    PreviewChrome(top: .playHUD, bottom: .toolbar)
}

#Preview("Island × Labeled") {
    PreviewChrome(top: .island, bottom: .labeled)
}

private struct PreviewChrome: View {
    @State private var model = ChromePreviewModel()
    let top: TopChromeKind
    let bottom: BottomChromeKind

    var body: some View {
        ZStack {
            ParkCanvas()
            ParkChromePlayground(model: model)
        }
        .onAppear {
            model.top = top
            model.bottom = bottom
        }
    }
}
