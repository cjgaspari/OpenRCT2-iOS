/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

import Observation
import SwiftUI
import UIKit

struct ScenarioPickerSnapshot: Decodable {
    let title: String
    let lockedTitle: String
    let lockedMessage: String
    let selectedSourceID: Int32
    let sources: [ScenarioPickerSource]
    let scenarios: [ScenarioPickerScenario]
}

struct ScenarioPickerSource: Decodable, Hashable, Identifiable {
    let id: Int32
    let title: String
    let shortTitle: String
    let scenarioCount: Int
    let showsCategories: Bool
}

struct ScenarioPickerScenario: Decodable, Hashable, Identifiable {
    let id: Int32
    let sourceID: Int32
    let categoryID: Int32
    let categoryTitle: String
    let title: String
    let details: String
    let objective: String
    let isLocked: Bool
    let completedBy: String?
    let companyValue: String?
    let debugPath: String?
}

@Observable
final class ScenarioPickerModel {
    var isPresented = false
    var snapshot: ScenarioPickerSnapshot?
    var selectedSourceID: Int32?
    var selectedScenarioID: Int32?
    var previewImage: UIImage?
    var isPreviewLoading = false
    var isStarting = false
    var presentationGeneration = 0

    @ObservationIgnored
    var onAction: ((Int32, Int32) -> Void)?

    @ObservationIgnored
    var onPresentationChanged: (() -> Void)?

    var selectedSource: ScenarioPickerSource? {
        guard let selectedSourceID else {
            return nil
        }
        return snapshot?.sources.first { $0.id == selectedSourceID }
    }

    var selectedScenario: ScenarioPickerScenario? {
        guard let selectedScenarioID else {
            return nil
        }
        return snapshot?.scenarios.first { $0.id == selectedScenarioID }
    }

    func scenarios(for sourceID: Int32) -> [ScenarioPickerScenario] {
        snapshot?.scenarios.filter { $0.sourceID == sourceID } ?? []
    }

    func present(snapshotJSON: String) {
        guard let data = snapshotJSON.data(using: .utf8) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode(ScenarioPickerSnapshot.self, from: data)
            snapshot = decoded
            selectedSourceID = decoded.sources.contains { $0.id == decoded.selectedSourceID }
                ? decoded.selectedSourceID
                : decoded.sources.first?.id
            selectedScenarioID = preferredScenarioID(in: selectedSourceID)
            previewImage = nil
            isPreviewLoading = false
            isStarting = false
            presentationGeneration += 1
            isPresented = true
            onPresentationChanged?()
            requestSelectedPreview()
        } catch {
            NSLog("[OpenRCT2Touch] native scenario picker: invalid snapshot: %@", String(describing: error))
        }
    }

    func dismissFromEngine() {
        isPresented = false
        isStarting = false
        isPreviewLoading = false
        previewImage = nil
        onPresentationChanged?()
    }

    func cancel() {
        queue(.scenarioCancel)
    }

    func selectSource(_ sourceID: Int32) {
        guard selectedSourceID != sourceID else {
            return
        }
        selectedSourceID = sourceID
        selectedScenarioID = preferredScenarioID(in: sourceID)
        previewImage = nil
        isPreviewLoading = false
        queue(.scenarioSource, extra: sourceID)
        requestSelectedPreview()
    }

    func selectScenario(_ scenarioID: Int32) {
        guard selectedScenarioID != scenarioID else {
            return
        }
        selectedScenarioID = scenarioID
        previewImage = nil
        isPreviewLoading = false
        requestSelectedPreview()
    }

    func start(_ scenario: ScenarioPickerScenario) {
        guard !scenario.isLocked, !isStarting else {
            return
        }
        isStarting = true
        queue(.scenarioStart, extra: scenario.id)
    }

    func setPreviewLoading(scenarioID: Int32, loading: Bool) {
        guard selectedScenarioID == scenarioID else {
            return
        }
        isPreviewLoading = loading
        if loading {
            previewImage = nil
        }
    }

    func setPreview(scenarioID: Int32, rgba: UnsafePointer<UInt8>?, width: Int32, height: Int32) {
        guard selectedScenarioID == scenarioID else {
            return
        }
        isPreviewLoading = false
        guard let rgba, width > 0, height > 0 else {
            previewImage = nil
            return
        }

        let byteCount = Int(width) * Int(height) * 4
        let data = Data(bytes: rgba, count: byteCount)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: Int(width),
                height: Int(height),
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: Int(width) * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            previewImage = nil
            return
        }
        previewImage = UIImage(cgImage: image)
    }

    private func preferredScenarioID(in sourceID: Int32?) -> Int32? {
        guard let sourceID else {
            return nil
        }
        let candidates = scenarios(for: sourceID)
        return candidates.first { !$0.isLocked }?.id ?? candidates.first?.id
    }

    private func requestSelectedPreview() {
        guard let scenario = selectedScenario, !scenario.isLocked else {
            return
        }
        isPreviewLoading = true
        queue(.scenarioPreview, extra: scenario.id)
    }

    private func queue(_ action: ParkChromeAction, extra: Int32 = ParkChromeAction.extraXor) {
        NSLog("[OpenRCT2Touch] native scenario picker: queued action %d extra %d", action.rawValue, extra)
        onAction?(action.rawValue, extra)
    }
}
