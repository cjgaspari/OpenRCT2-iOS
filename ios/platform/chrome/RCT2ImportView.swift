// Copyright (c) 2026 OpenRCT2 Touch contributors
// OpenRCT2 Touch is licensed under the GNU General Public License version 3.

import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
private final class RCT2ImportPanelModel: ObservableObject {
    enum PickerKind {
        case zip
        case folder

        var contentTypes: [UTType] {
            switch self {
            case .zip:
                return [.zip]
            case .folder:
                return [.folder]
            }
        }
    }

    @Published var isDropTargeted = false
    @Published var isShowingPicker = false
    @Published var pickerKind: PickerKind = .zip
    @Published var errorMessage: String?

    private let onSelection: (URL?) -> Void

    init(onSelection: @escaping (URL?) -> Void) {
        self.onSelection = onSelection
    }

    func showPicker(_ kind: PickerKind) {
        pickerKind = kind
        errorMessage = nil
        isShowingPicker = true
    }

    func receive(_ urls: [URL]) -> Bool {
        guard let url = urls.first else {
            return false
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
            if values.isDirectory == true || values.contentType?.conforms(to: .zip) == true
                || url.pathExtension.caseInsensitiveCompare("zip") == .orderedSame
            {
                errorMessage = nil
                onSelection(url)
                return true
            }
        } catch {
            errorMessage = "OpenRCT2 Touch couldn't inspect that item. Try choosing it from Files instead."
            return false
        }

        errorMessage = "Choose an RCT2 folder or a ZIP containing Data/g1.dat."
        return false
    }

    func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            _ = receive(urls)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        onSelection(nil)
    }
}

private struct RCT2ImportPanel: View {
    @ObservedObject var model: RCT2ImportPanelModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            importCard
                .padding(24)
                .frame(maxWidth: 600)
        }
        .fileImporter(
            isPresented: $model.isShowingPicker,
            allowedContentTypes: model.pickerKind.contentTypes,
            allowsMultipleSelection: false,
            onCompletion: model.handlePickerResult
        )
    }

    private var importCard: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Import RollerCoaster Tycoon 2")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Use your own game files. Drop a ZIP below, or choose a ZIP or installation folder from Files.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }

            dropTarget

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    chooseZIPButton
                    chooseFolderButton
                }

                VStack(spacing: 12) {
                    chooseZIPButton
                    chooseFolderButton
                }
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Button("Not Now", role: .cancel) {
                model.cancel()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(28)
        .modifier(ImportCardGlass())
        .animation(.easeInOut(duration: 0.18), value: model.errorMessage)
    }

    private var dropTarget: some View {
        VStack(spacing: 10) {
            Image(systemName: model.isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.system(size: 34, weight: .medium))
            Text(model.isDropTargeted ? "Release to Import" : "Drop RCT2 ZIP Here")
                .font(.headline)
            Text("The ZIP may contain the files directly or inside one enclosing folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.horizontal, 18)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(DropTargetGlass(isTargeted: model.isDropTargeted))
        .dropDestination(for: URL.self) { urls, _ in
            model.receive(urls)
        } isTargeted: { targeted in
            model.isDropTargeted = targeted
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drop an RCT2 ZIP file here")
    }

    private var chooseZIPButton: some View {
        Button("Choose ZIP", systemImage: "archivebox") {
            model.showPicker(.zip)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    private var chooseFolderButton: some View {
        Button("Choose Folder", systemImage: "folder") {
            model.showPicker(.folder)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

private struct ImportCardGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 30))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }
}

private struct DropTargetGlass: ViewModifier {
    let isTargeted: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isTargeted ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                    in: .rect(cornerRadius: 20)
                )
        } else {
            content
                .background(
                    isTargeted ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
    }
}

typealias RCT2ImportSelectionCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?,
    Int32
) -> Void

@MainActor
private final class RCT2ImportPanelSession: NSObject {
    private let context: UnsafeMutableRawPointer?
    private let callback: RCT2ImportSelectionCallback
    private var host: UIViewController?
    private var completed = false

    private lazy var model = RCT2ImportPanelModel { [weak self] url in
        self?.finish(with: url)
    }

    init(context: UnsafeMutableRawPointer?, callback: @escaping RCT2ImportSelectionCallback) {
        self.context = context
        self.callback = callback
    }

    func present(on presenter: UIViewController) {
        let hostingController = UIHostingController(rootView: RCT2ImportPanel(model: model))
        hostingController.view.backgroundColor = .clear
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        host = hostingController
        presenter.present(hostingController, animated: true)
    }

    private func finish(with url: URL?) {
        guard !completed else {
            return
        }
        completed = true

        let completion = { [context, callback] in
            if let url {
                let pointer = Unmanaged.passUnretained(url as NSURL).toOpaque()
                callback(context, pointer, 0)
            } else {
                callback(context, nil, 1)
            }
        }

        if let host, host.presentingViewController != nil {
            host.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
        self.host = nil
    }
}

@_cdecl("OpenRCT2TouchPresentRCT2ImportPanel")
@MainActor
func OpenRCT2TouchPresentRCT2ImportPanel(
    _ presenterPointer: UnsafeMutableRawPointer?,
    _ context: UnsafeMutableRawPointer?,
    _ callback: RCT2ImportSelectionCallback?
) -> UnsafeMutableRawPointer? {
    guard let presenterPointer, let callback else {
        return nil
    }

    let presenter = Unmanaged<UIViewController>.fromOpaque(presenterPointer).takeUnretainedValue()
    let session = RCT2ImportPanelSession(context: context, callback: callback)
    session.present(on: presenter)
    return Unmanaged.passRetained(session).toOpaque()
}

@_cdecl("OpenRCT2TouchReleaseRCT2ImportPanel")
@MainActor
func OpenRCT2TouchReleaseRCT2ImportPanel(_ sessionPointer: UnsafeMutableRawPointer?) {
    guard let sessionPointer else {
        return
    }
    _ = Unmanaged<RCT2ImportPanelSession>.fromOpaque(sessionPointer).takeRetainedValue()
}
