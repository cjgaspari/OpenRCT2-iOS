/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import Observation
import SwiftUI

struct LoadSaveSnapshot: Decodable {
    let isSave: Bool
    let title: String
    let defaultName: String
    let emptyMessage: String
    let files: [LoadSaveFile]
}

struct LoadSaveFile: Decodable, Hashable, Identifiable {
    let id: Int32
    let name: String
    let detail: String
    let isLoaded: Bool
}

@Observable
final class LoadSaveModel {
    var isPresented = false
    var snapshot: LoadSaveSnapshot?
    var saveName = ""
    var presentationGeneration = 0

    @ObservationIgnored
    var onAction: ((Int32, Int32) -> Void)?

    @ObservationIgnored
    var onPresentationChanged: (() -> Void)?

    var isSave: Bool {
        snapshot?.isSave ?? false
    }

    var files: [LoadSaveFile] {
        snapshot?.files ?? []
    }

    func present(snapshotJSON: String) {
        guard let data = snapshotJSON.data(using: .utf8) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode(LoadSaveSnapshot.self, from: data)
            snapshot = decoded
            saveName = decoded.defaultName
            presentationGeneration += 1
            isPresented = true
            onPresentationChanged?()
        } catch {
            NSLog("[OpenRCT2Touch] native load/save: invalid snapshot: %@", String(describing: error))
        }
    }

    func dismissFromEngine() {
        isPresented = false
        onPresentationChanged?()
    }

    func cancel() {
        queue(.loadSaveCancel)
    }

    func load(_ file: LoadSaveFile) {
        queue(.loadSaveSelect, extra: file.id)
    }

    func overwrite(_ file: LoadSaveFile) {
        queue(.loadSaveSelect, extra: file.id)
    }

    func commitSave() {
        queue(.loadSaveCommit)
    }

    var trimmedSaveName: String {
        saveName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var existingFileForSaveName: LoadSaveFile? {
        let target = trimmedSaveName.lowercased()
        guard !target.isEmpty else {
            return nil
        }
        return files.first { $0.name.lowercased() == target }
    }

    private func queue(_ action: ParkChromeAction, extra: Int32 = ParkChromeAction.extraXor) {
        NSLog("[OpenRCT2Touch] native load/save: queued action %d extra %d", action.rawValue, extra)
        onAction?(action.rawValue, extra)
    }
}
