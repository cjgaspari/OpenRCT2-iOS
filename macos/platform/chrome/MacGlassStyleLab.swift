/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Live Mac Glass Style Dev Panel — every knob applies immediately to
 * registered scenario/load (and other) MacGlassPanelHost windows.
 * Hotkey: ⌥⌘G. Also opened from Debug Paint.
 *****************************************************************************/

import AppKit
import SwiftUI

enum MacGlassStyleLab {
    @MainActor private static var panel: NSPanel?
    @MainActor private static var hotkeyInstalled = false

    @MainActor
    static func show() -> Bool {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }

        // Lab itself stays readable: standard floating panel (not under test glass).
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Glass Style Lab"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 420)

        let host = NSHostingView(rootView: GlassStyleLabView {
            panel.close()
            Self.panel = nil
        })
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Self.panel = panel
        installHotkeyIfNeeded()
        return true
    }

    @MainActor
    static func installHotkeyIfNeeded() {
        guard !hotkeyInstalled else { return }
        hotkeyInstalled = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌥⌘G
            if event.modifierFlags.contains([.command, .option]),
               event.charactersIgnoringModifiers?.lowercased() == "g"
            {
                _ = show()
                return nil
            }
            return event
        }
    }
}

private struct GlassStyleLabView: View {
    let onClose: () -> Void
    @Bindable private var knobs = MacGlassStyleKnobs.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                GroupBox("Glass chrome") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Clear glass (off = Regular)", isOn: binding(\.useClearGlass))
                        labeledSlider("Corner radius", value: binding(\.cornerRadius), range: 0...36)
                        Toggle("Tint enabled", isOn: binding(\.tintEnabled))
                        if knobs.tintEnabled {
                            labeledSlider("Tint hue", value: binding(\.tintHue), range: 0...1)
                            labeledSlider("Tint saturation", value: binding(\.tintSaturation), range: 0...1)
                            labeledSlider("Tint brightness", value: binding(\.tintBrightness), range: 0...1)
                            labeledSlider("Tint opacity", value: binding(\.tintOpacity), range: 0...1)
                        }
                        Toggle("Force darkAqua appearance", isOn: binding(\.forceDarkAqua))
                    }
                    .padding(6)
                }

                GroupBox("Text plates / frost") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Localized frost (off = full wash)", isOn: binding(\.localizedFrost))
                        Toggle("thinMaterial under text", isOn: binding(\.useThinMaterial))
                        labeledSlider("Material opacity", value: binding(\.materialOpacity), range: 0...1)
                        labeledSlider("Dark dimming", value: binding(\.dimmingOpacity), range: 0...1)
                        labeledSlider("Plate corner radius", value: binding(\.plateCornerRadius), range: 0...24)
                    }
                    .padding(6)
                }

                GroupBox("Labels") {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledSlider("Primary white", value: binding(\.primaryWhite), range: 0...1)
                        labeledSlider("Secondary white", value: binding(\.secondaryWhite), range: 0...1)
                        HStack {
                            Text("Aa primary")
                                .foregroundStyle(knobs.primaryLabel)
                                .font(.title3.weight(.semibold))
                            Text("Aa secondary")
                                .foregroundStyle(knobs.secondaryLabel)
                                .font(.caption)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background {
                            ZStack {
                                LinearGradient(
                                    colors: [.cyan, .blue, .white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                MacGlassTextPlate(cornerRadius: 8)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(6)
                }

                HStack {
                    Button("Reset defaults") {
                        knobs.resetDefaults()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Close", action: onClose)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass Style Lab")
                .font(.title3.weight(.semibold))
            Text("Live knobs → open scenario / load panels. Hotkey ⌥⌘G.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<MacGlassStyleKnobs, Bool>) -> Binding<Bool> {
        Binding(
            get: { knobs[keyPath: keyPath] },
            set: {
                knobs[keyPath: keyPath] = $0
                knobs.applyChrome()
            }
        )
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<MacGlassStyleKnobs, Double>) -> Binding<Double> {
        Binding(
            get: { knobs[keyPath: keyPath] },
            set: {
                knobs[keyPath: keyPath] = $0
                knobs.applyChrome()
            }
        )
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .controlSize(.small)
        }
    }
}

@_cdecl("OpenRCT2MacNativeGlassStyleLabShow")
func OpenRCT2MacNativeGlassStyleLabShow() -> Bool {
    MainActor.assumeIsolated { MacGlassStyleLab.show() }
}
