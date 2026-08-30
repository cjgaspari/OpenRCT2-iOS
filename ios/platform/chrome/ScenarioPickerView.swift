/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

struct ScenarioPickerRootView: View {
    @Bindable var model: ScenarioPickerModel

    var body: some View {
        // An inert anchor: the browser is presented as a native medium sheet so
        // it reads like the View/Build tools rather than covering the whole scene.
        Color.clear
            .allowsHitTesting(false)
            .sheet(isPresented: sheetPresented) {
                ScenarioPickerBrowser(model: model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .presentationSizing(.page)
            }
    }

    // Routes a user-driven swipe-dismiss through the engine cancel path while
    // letting the engine remain the source of truth for `isPresented`.
    private var sheetPresented: Binding<Bool> {
        Binding(
            get: { model.isPresented },
            set: { newValue in
                if !newValue, model.isPresented {
                    model.cancel()
                }
            }
        )
    }
}

struct ScenarioPickerBrowser: View {
    @Bindable var model: ScenarioPickerModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var path: [ScenarioPickerScenario] = []

    var body: some View {
        GeometryReader { proxy in
            NavigationStack(path: $path) {
                Group {
                    if let snapshot = model.snapshot {
                        if usesColumns(width: proxy.size.width) {
                            columnBrowser(snapshot: snapshot)
                        } else {
                            compactBrowser(snapshot: snapshot)
                        }
                    } else {
                        ProgressView("Loading scenarios…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle(model.snapshot?.title ?? "Select Scenario")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            model.cancel()
                        }
                        .accessibilityIdentifier("openrct2.touch.scenario.close")
                    }
                }
                .navigationDestination(for: ScenarioPickerScenario.self) { scenario in
                    ScenarioPickerDetail(model: model, scenario: scenario, embedded: false)
                        .onAppear {
                            model.selectScenario(scenario.id)
                        }
                }
            }
        }
        .tint(.blue)
        .onChange(of: model.presentationGeneration) {
            path.removeAll()
        }
    }

    private func usesColumns(width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 720
    }

    private func columnBrowser(snapshot: ScenarioPickerSnapshot) -> some View {
        HStack(spacing: 0) {
            ScenarioSourceSidebar(model: model, sources: snapshot.sources)
                .frame(width: 190)
            Divider()
            ScenarioPickerList(model: model, usesNavigationLinks: false)
                .frame(minWidth: 310, idealWidth: 390, maxWidth: 470)
            Divider()
            ScenarioPickerDetail(model: model, scenario: model.selectedScenario, embedded: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func compactBrowser(snapshot: ScenarioPickerSnapshot) -> some View {
        VStack(spacing: 0) {
            ScenarioSourceStrip(model: model, sources: snapshot.sources)
            Divider()
            ScenarioPickerList(model: model, usesNavigationLinks: true)
        }
    }
}

private struct ScenarioSourceSidebar: View {
    let model: ScenarioPickerModel
    let sources: [ScenarioPickerSource]

    var body: some View {
        List(sources) { source in
            Button {
                model.selectSource(source.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ScenarioSourceSymbol.name(for: source.id))
                        .frame(width: 24)
                        .foregroundStyle(source.id == model.selectedSourceID ? .white : .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(source.id == model.selectedSourceID ? .white : .primary)
                        Text("\(source.scenarioCount) scenarios")
                            .font(.caption)
                            .foregroundStyle(source.id == model.selectedSourceID ? .white.opacity(0.82) : .secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(source.id == model.selectedSourceID ? Color.accentColor : Color.clear)
            .accessibilityAddTraits(source.id == model.selectedSourceID ? .isSelected : [])
            .accessibilityIdentifier("openrct2.touch.scenario.source.\(source.id)")
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

private struct ScenarioSourceStrip: View {
    let model: ScenarioPickerModel
    let sources: [ScenarioPickerSource]

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(sources) { source in
                        Button {
                            model.selectSource(source.id)
                        } label: {
                            Label(source.shortTitle, systemImage: ScenarioSourceSymbol.name(for: source.id))
                                .font(.subheadline.weight(.semibold))
                        }
                        .modifier(ScenarioSourceChipGlass(selected: source.id == model.selectedSourceID))
                        .accessibilityAddTraits(source.id == model.selectedSourceID ? .isSelected : [])
                        .accessibilityIdentifier("openrct2.touch.scenario.source.\(source.id)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct ScenarioSourceChipGlass: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content.buttonStyle(.glassProminent).tint(.accentColor)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

private struct ScenarioPickerList: View {
    let model: ScenarioPickerModel
    let usesNavigationLinks: Bool

    private var scenarios: [ScenarioPickerScenario] {
        guard let sourceID = model.selectedSourceID else {
            return []
        }
        return model.scenarios(for: sourceID)
    }

    var body: some View {
        List {
            if model.selectedSource?.showsCategories == true {
                ForEach(categoryIDs, id: \.self) { categoryID in
                    let matches = scenarios.filter { $0.categoryID == categoryID }
                    if let first = matches.first {
                        Section(first.categoryTitle) {
                            rows(matches)
                        }
                    }
                }
            } else {
                Section {
                    rows(scenarios)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 52)
        .overlay {
            if scenarios.isEmpty {
                ContentUnavailableView(
                    "No Scenarios",
                    systemImage: "flag.checkered",
                    description: Text("No scenarios from this source are installed.")
                )
            }
        }
    }

    private var categoryIDs: [Int32] {
        var seen = Set<Int32>()
        return scenarios.compactMap { scenario in
            seen.insert(scenario.categoryID).inserted ? scenario.categoryID : nil
        }
    }

    @ViewBuilder
    private func rows(_ scenarios: [ScenarioPickerScenario]) -> some View {
        ForEach(scenarios) { scenario in
            if usesNavigationLinks {
                NavigationLink(value: scenario) {
                    ScenarioPickerRow(scenario: scenario, selected: false)
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("openrct2.touch.scenario.row.\(scenario.id)")
            } else {
                Button {
                    model.selectScenario(scenario.id)
                } label: {
                    ScenarioPickerRow(
                        scenario: scenario,
                        selected: scenario.id == model.selectedScenarioID
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    scenario.id == model.selectedScenarioID ? Color.accentColor.opacity(0.14) : Color.clear
                )
                .accessibilityAddTraits(scenario.id == model.selectedScenarioID ? .isSelected : [])
                .accessibilityIdentifier("openrct2.touch.scenario.row.\(scenario.id)")
            }
        }
    }
}

private struct ScenarioPickerRow: View {
    let scenario: ScenarioPickerScenario
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(scenario.title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(scenario.isLocked ? .secondary : .primary)
                if let completedBy = scenario.completedBy {
                    Text("Completed by \(completedBy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if scenario.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            } else if scenario.completedBy != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Completed")
            }
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
    }
}

private struct ScenarioPickerDetail: View {
    let model: ScenarioPickerModel
    let scenario: ScenarioPickerScenario?
    let embedded: Bool

    var body: some View {
        if let scenario {
            configuredDetail(scenario)
        } else {
            ContentUnavailableView(
                "Choose a Scenario",
                systemImage: "flag.checkered",
                description: Text("Select a scenario to see its preview, description, objective, and best result.")
            )
        }
    }

    @ViewBuilder
    private func configuredDetail(_ scenario: ScenarioPickerScenario) -> some View {
        if embedded {
            detailContent(scenario)
        } else {
            detailContent(scenario)
                .navigationTitle(scenario.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Close", systemImage: "xmark") {
                            model.cancel()
                        }
                        .accessibilityIdentifier("openrct2.touch.scenario.close")
                    }
                }
        }
    }

    private func detailContent(_ scenario: ScenarioPickerScenario) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScenarioPickerPreview(model: model, scenario: scenario)
                    .overlay {
                        if !scenario.isLocked {
                            ScenarioStartButton(model: model, scenario: scenario)
                        }
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(scenario.title)
                        .font(.title2.bold())
                    if model.selectedSource?.showsCategories == true {
                        Text(scenario.categoryTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if scenario.isLocked {
                    Label(model.snapshot?.lockedTitle ?? "Scenario Locked", systemImage: "lock.fill")
                        .font(.headline)
                    Text(model.snapshot?.lockedMessage ?? "Complete earlier scenarios to unlock this scenario.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(scenario.details)
                        .font(.body)

                    detailSection(title: "Objective", text: scenario.objective)

                    if let completedBy = scenario.completedBy {
                        detailSection(
                            title: "Best Result",
                            text: "Completed by \(completedBy) with a company value of \(scenario.companyValue ?? "—")."
                        )
                    }

                    if let debugPath = scenario.debugPath {
                        detailSection(title: "Path", text: debugPath)
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ScenarioStartButton: View {
    let model: ScenarioPickerModel
    let scenario: ScenarioPickerScenario

    var body: some View {
        Button {
            model.start(scenario)
        } label: {
            if model.isStarting {
                ProgressView()
                    .tint(.white)
                    .frame(minWidth: 96)
            } else {
                Label("Play", systemImage: "play.fill")
                    .font(.headline)
            }
        }
        .buttonStyle(.glassProminent)
        .tint(.green)
        .controlSize(.large)
        .disabled(model.isStarting)
        .accessibilityIdentifier("openrct2.touch.scenario.start")
    }
}

private struct ScenarioPickerPreview: View {
    let model: ScenarioPickerModel
    let scenario: ScenarioPickerScenario

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.quaternary)

            if scenario.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else if model.isPreviewLoading {
                ProgressView("Loading preview…")
            } else if let image = model.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 18))
            } else {
                ContentUnavailableView("Preview Unavailable", systemImage: "photo")
            }
        }
        .aspectRatio(5 / 4, contentMode: .fit)
        .frame(maxWidth: 500)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
        }
        .accessibilityLabel(scenario.isLocked ? "Locked scenario" : "Scenario preview")
    }
}

private enum ScenarioSourceSymbol {
    static func name(for sourceID: Int32) -> String {
        switch sourceID {
        case 0, 1, 2:
            "leaf.fill"
        case 3:
            "flag.checkered"
        case 4:
            "globe.americas.fill"
        case 5:
            "clock.fill"
        case 6:
            "person.3.fill"
        case 7:
            "building.columns.fill"
        case 8:
            "shippingbox.fill"
        default:
            "folder.fill"
        }
    }
}
