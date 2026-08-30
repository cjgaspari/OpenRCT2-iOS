/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import SwiftUI

struct LoadSaveRootView: View {
    @Bindable var model: LoadSaveModel

    var body: some View {
        // Inert anchor: the browser is presented as a native medium glass sheet,
        // matching the scenario picker.
        Color.clear
            .allowsHitTesting(false)
            .sheet(isPresented: sheetPresented) {
                LoadSaveBrowser(model: model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .presentationSizing(.page)
            }
    }

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

struct LoadSaveBrowser: View {
    @Bindable var model: LoadSaveModel
    @FocusState private var nameFieldFocused: Bool
    @State private var overwriteTarget: LoadSaveFile?

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = model.snapshot {
                    list(snapshot)
                } else {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(model.snapshot?.title ?? (model.isSave ? "Save Park" : "Load Park"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        model.cancel()
                    }
                    .accessibilityIdentifier("openrct2.touch.loadsave.close")
                }
            }
        }
        .tint(.blue)
        .onChange(of: model.presentationGeneration) {
            overwriteTarget = nil
            nameFieldFocused = false
        }
        .alert("Overwrite Park?", isPresented: overwriteAlertPresented, presenting: overwriteTarget) { file in
            Button("Overwrite", role: .destructive) {
                model.overwrite(file)
            }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("“\(file.name)” already exists. Overwriting replaces the saved park.")
        }
    }

    private func list(_ snapshot: LoadSaveSnapshot) -> some View {
        List {
            if snapshot.isSave {
                Section("Save As") {
                    TextField("Park name", text: $model.saveName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFieldFocused)
                        .onSubmit(attemptSave)
                        .listRowBackground(Color.clear)

                    Button(action: attemptSave) {
                        Label("Save", systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .disabled(model.trimmedSaveName.isEmpty)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("openrct2.touch.loadsave.save")
                }
            }

            Section {
                if snapshot.files.isEmpty {
                    ContentUnavailableView(
                        snapshot.isSave ? "No Saved Parks" : "Nothing to Load",
                        systemImage: "tray",
                        description: Text(snapshot.emptyMessage)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(snapshot.files) { file in
                        Button {
                            select(file)
                        } label: {
                            LoadSaveRow(file: file)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("openrct2.touch.loadsave.row.\(file.id)")
                    }
                }
            } header: {
                if snapshot.isSave {
                    Text("Existing Parks")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 52)
    }

    private func select(_ file: LoadSaveFile) {
        if model.isSave {
            overwriteTarget = file
        } else {
            model.load(file)
        }
    }

    private func attemptSave() {
        guard !model.trimmedSaveName.isEmpty else {
            return
        }
        nameFieldFocused = false
        if let existing = model.existingFileForSaveName {
            overwriteTarget = existing
        } else {
            model.commitSave()
        }
    }

    private var overwriteAlertPresented: Binding<Bool> {
        Binding(
            get: { overwriteTarget != nil },
            set: { newValue in
                if !newValue {
                    overwriteTarget = nil
                }
            }
        )
    }
}

private struct LoadSaveRow: View {
    let file: LoadSaveFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if !file.detail.isEmpty {
                    Text(file.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if file.isLoaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Currently loaded")
            }
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
    }
}
