import SwiftUI

struct ParkToolsSheet: View {
    @Bindable var model: ChromePreviewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Build") {
                    ForEach(ParkMenuCatalog.overflowBuild) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section("View") {
                    ForEach(ParkMenuCatalog.view) { item in
                        Button {
                            select(item)
                        } label: {
                            MenuRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                    }
                    ForEach(ParkMenuCatalog.viewToggles, id: \.self) { name in
                        Toggle(name, isOn: $model[viewFlag: name])
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("Park tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismissSheet() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationSizing(.page)
    }

    private func select(_ item: ParkMenuItem) {
        dismissSheet()
        model.toolTapped(item.window)
    }

    private func dismissSheet() {
        model.isShowingParkTools = false
        dismiss()
    }
}
