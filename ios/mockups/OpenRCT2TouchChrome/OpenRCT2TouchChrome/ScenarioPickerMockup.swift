/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

struct ScenarioPickerMockup: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSourceID = MockScenarioSource.rct2.id
    @State private var selectedScenarioID: MockScenario.ID? = MockScenario.fixture[1].id
    @State private var path: [MockScenario] = ProcessInfo.processInfo.arguments.contains("--scenario-picker-detail")
        ? [MockScenario.fixture[1]]
        : []

    private var scenarios: [MockScenario] {
        MockScenario.fixture.filter { $0.sourceID == selectedSourceID }
    }

    private var selectedScenario: MockScenario? {
        scenarios.first { $0.id == selectedScenarioID }
    }

    var body: some View {
        GeometryReader { proxy in
            NavigationStack(path: $path) {
                Group {
                    if usesColumns(width: proxy.size.width) {
                        columnBrowser
                    } else {
                        compactBrowser
                    }
                }
                .navigationTitle("Select Scenario")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {}
                    }
                }
                .navigationDestination(for: MockScenario.self) { scenario in
                    ScenarioMockDetail(scenario: scenario)
                }
            }
        }
        .tint(.blue)
    }

    private func usesColumns(width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 720
    }

    private var columnBrowser: some View {
        HStack(spacing: 0) {
            sourceSidebar
                .frame(width: 190)
            Divider()
            scenarioList(compact: false)
                .frame(minWidth: 310, idealWidth: 390, maxWidth: 470)
            Divider()
            ScenarioMockDetail(scenario: selectedScenario)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var compactBrowser: some View {
        VStack(spacing: 0) {
            sourceStrip
            Divider()
            scenarioList(compact: true)
        }
    }

    private var sourceSidebar: some View {
        List(MockScenarioSource.fixture) { source in
            Button {
                selectSource(source)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: source.symbol)
                        .frame(width: 24)
                        .foregroundStyle(source.id == selectedSourceID ? .white : .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(source.id == selectedSourceID ? .white : .primary)
                        Text("\(source.count) scenarios")
                            .font(.caption)
                            .foregroundStyle(source.id == selectedSourceID ? .white.opacity(0.82) : .secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(source.id == selectedSourceID ? Color.accentColor : Color.clear)
            .accessibilityAddTraits(source.id == selectedSourceID ? .isSelected : [])
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var sourceStrip: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(MockScenarioSource.fixture) { source in
                        Button {
                            selectSource(source)
                        } label: {
                            Label(source.shortTitle, systemImage: source.symbol)
                                .font(.subheadline.weight(.semibold))
                        }
                        .modifier(MockSourceChipGlass(selected: source.id == selectedSourceID))
                        .accessibilityAddTraits(source.id == selectedSourceID ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func scenarioList(compact: Bool) -> some View {
        List {
            ForEach(MockScenarioCategory.allCases) { category in
                let matches = scenarios.filter { $0.category == category }
                if !matches.isEmpty {
                    Section(category.title) {
                        ForEach(matches) { scenario in
                            if compact {
                                NavigationLink(value: scenario) {
                                    ScenarioMockRow(scenario: scenario, selected: false)
                                }
                                .listRowBackground(Color.clear)
                            } else {
                                Button {
                                    selectedScenarioID = scenario.id
                                } label: {
                                    ScenarioMockRow(
                                        scenario: scenario,
                                        selected: scenario.id == selectedScenarioID
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    scenario.id == selectedScenarioID ? Color.accentColor.opacity(0.14) : Color.clear
                                )
                            }
                        }
                    }
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

    private func selectSource(_ source: MockScenarioSource) {
        selectedSourceID = source.id
        selectedScenarioID = MockScenario.fixture.first {
            $0.sourceID == source.id && !$0.isLocked
        }?.id
    }
}

private struct MockSourceChipGlass: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content.buttonStyle(.glassProminent).tint(.accentColor)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

private struct ScenarioMockRow: View {
    let scenario: MockScenario
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

private struct ScenarioMockDetail: View {
    let scenario: MockScenario?

    var body: some View {
        Group {
            if let scenario {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScenarioPreviewPlaceholder(isLocked: scenario.isLocked)
                            .overlay {
                                if !scenario.isLocked {
                                    Button {
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.glassProminent)
                                    .tint(.green)
                                    .controlSize(.large)
                                }
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(scenario.title)
                                .font(.title2.bold())
                            Text(scenario.category.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if scenario.isLocked {
                            Label("Scenario Locked", systemImage: "lock.fill")
                                .font(.headline)
                            Text("Complete earlier scenarios to unlock this scenario.")
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
                        }
                    }
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .navigationTitle(scenario.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Choose a Scenario",
                    systemImage: "flag.checkered",
                    description: Text("Select a scenario to see its preview, description, objective, and best result.")
                )
            }
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

private struct ScenarioPreviewPlaceholder: View {
    let isLocked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    isLocked
                        ? LinearGradient(colors: [.gray.opacity(0.45), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.green.opacity(0.8), .cyan.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                HStack(spacing: 18) {
                    Image(systemName: "tree.fill")
                    Image(systemName: "tram.fill")
                    Image(systemName: "tent.2.fill")
                }
                .font(.system(size: 38))
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .aspectRatio(5 / 4, contentMode: .fit)
        .frame(maxWidth: 500)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .accessibilityLabel(isLocked ? "Locked scenario" : "Scenario preview")
    }
}

private struct MockScenarioSource: Identifiable {
    let id: Int
    let title: String
    let shortTitle: String
    let symbol: String
    let count: Int

    static let rct2 = Self(id: 3, title: "RollerCoaster Tycoon 2", shortTitle: "RCT2", symbol: "flag.checkered", count: 8)
    static let fixture: [Self] = [
        rct2,
        .init(id: 4, title: "Expansion One", shortTitle: "Expansion 1", symbol: "globe.americas.fill", count: 5),
        .init(id: 5, title: "Expansion Two", shortTitle: "Expansion 2", symbol: "clock.fill", count: 4),
        .init(id: 7, title: "Real Parks", shortTitle: "Real Parks", symbol: "building.columns.fill", count: 3),
        .init(id: 8, title: "Extras", shortTitle: "Extras", symbol: "shippingbox.fill", count: 2),
    ]
}

private enum MockScenarioCategory: Int, CaseIterable, Identifiable {
    case beginner
    case challenging
    case expert

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner Parks"
        case .challenging: "Challenging Parks"
        case .expert: "Expert Parks"
        }
    }
}

private struct MockScenario: Identifiable, Hashable {
    let id: Int
    let sourceID: Int
    let category: MockScenarioCategory
    let title: String
    let details: String
    let objective: String
    let isLocked: Bool
    let completedBy: String?
    let companyValue: String?

    static let fixture: [Self] = [
        .init(id: 1, sourceID: 3, category: .beginner, title: "Meadow Fields", details: "Turn an open meadow into a welcoming family park.", objective: "Welcome 800 guests by the end of Year 3 with a park rating of at least 600.", isLocked: false, completedBy: "Player", companyValue: "$42,180"),
        .init(id: 2, sourceID: 3, category: .beginner, title: "Castle Gardens", details: "You have inherited a compact castle park. Expand carefully around its historic walls.", objective: "Welcome 1,500 guests by October, Year 4, with a park rating of at least 600.", isLocked: false, completedBy: nil, companyValue: nil),
        .init(id: 3, sourceID: 3, category: .beginner, title: "Factory Crossing", details: "Reconnect two sections of an old industrial estate with rides and paths.", objective: "Achieve a park value of $60,000 by the end of Year 3.", isLocked: false, completedBy: nil, companyValue: nil),
        .init(id: 4, sourceID: 3, category: .challenging, title: "Cliffside Lake", details: "Build a profitable park around steep cliffs and a narrow lake.", objective: "Repay the loan and achieve a park value of $80,000.", isLocked: true, completedBy: nil, companyValue: nil),
        .init(id: 5, sourceID: 3, category: .challenging, title: "Harbour Heights", details: "A seaside site with limited flat ground and strong winds.", objective: "Build ten roller coasters with an excitement rating of at least 6.00.", isLocked: true, completedBy: nil, companyValue: nil),
        .init(id: 6, sourceID: 3, category: .expert, title: "Summit Gardens", details: "A demanding mountain site intended for experienced park managers.", objective: "Finish five roller coasters with an excitement rating of at least 7.00.", isLocked: true, completedBy: nil, companyValue: nil),
        .init(id: 7, sourceID: 4, category: .beginner, title: "Coastal Discovery", details: "Create a compact destination on a sheltered coast.", objective: "Welcome 1,000 guests by the end of Year 3.", isLocked: false, completedBy: nil, companyValue: nil),
        .init(id: 8, sourceID: 5, category: .beginner, title: "Clockwork Park", details: "Revitalise a small park built around a clock tower.", objective: "Achieve a park value of $50,000 by the end of Year 3.", isLocked: false, completedBy: nil, companyValue: nil),
        .init(id: 9, sourceID: 7, category: .beginner, title: "Riverside Landmark", details: "Manage a recreation of a real riverside park.", objective: "Have fun and build a park you are proud of.", isLocked: false, completedBy: nil, companyValue: nil),
        .init(id: 10, sourceID: 8, category: .beginner, title: "Community Challenge", details: "A community-created scenario with an unusual starting layout.", objective: "Welcome 1,200 guests and maintain a rating of at least 700.", isLocked: false, completedBy: nil, companyValue: nil),
    ]
}

#Preview("Scenario Picker — iPhone") {
    ScenarioPickerMockup()
        .frame(width: 420, height: 900)
}

#Preview("Scenario Picker — iPad") {
    ScenarioPickerMockup()
        .frame(width: 1_180, height: 820)
}
