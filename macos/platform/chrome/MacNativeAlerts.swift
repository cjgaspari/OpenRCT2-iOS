/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * CJ HIG lock: Tier 1 confirms = system NSAlert (choice A).
 *****************************************************************************/

import AppKit

enum MacNativeAlerts {
    /// Returns 0 / 1 / 2 for first / second / third button. -1 if cancelled oddly.
    @MainActor
    static func confirm(
        title: String,
        message: String,
        button0: String,
        button1: String?,
        button2: String?
    ) -> Int32 {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: button0)
        if let button1 {
            alert.addButton(withTitle: button1)
        }
        if let button2 {
            alert.addButton(withTitle: button2)
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            return 0
        case .alertSecondButtonReturn:
            return 1
        case .alertThirdButtonReturn:
            return 2
        default:
            return -1
        }
    }
}

@_cdecl("OpenRCT2MacNativeAlertConfirm")
func OpenRCT2MacNativeAlertConfirm(
    _ title: UnsafePointer<CChar>?,
    _ message: UnsafePointer<CChar>?,
    _ button0: UnsafePointer<CChar>?,
    _ button1: UnsafePointer<CChar>?,
    _ button2: UnsafePointer<CChar>?
) -> Int32 {
    let t = title.map { String(cString: $0) } ?? ""
    let m = message.map { String(cString: $0) } ?? ""
    let b0 = button0.map { String(cString: $0) } ?? "OK"
    let b1 = button1.map { String(cString: $0) }
    let b2 = button2.map { String(cString: $0) }
    return MainActor.assumeIsolated {
        MacNativeAlerts.confirm(title: t, message: m, button0: b0, button1: b1, button2: b2)
    }
}

// MARK: - Text input (1.9)

enum MacNativeTextInput {
    /// Returns true if OK pressed; writes result into `out`.
    @MainActor
    static func prompt(title: String, message: String, initial: String, out: UnsafeMutablePointer<CChar>, outLen: Int) -> Int32 {
        let alert = NSAlert()
        alert.messageText = title.isEmpty ? "Enter Text" : title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = initial
        field.isEditable = true
        field.isBordered = true
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return 0 }

        let value = field.stringValue
        _ = value.withCString { src in
            strlcpy(out, src, outLen)
        }
        return 1
    }
}

@_cdecl("OpenRCT2MacNativeTextInput")
func OpenRCT2MacNativeTextInput(
    _ title: UnsafePointer<CChar>?,
    _ message: UnsafePointer<CChar>?,
    _ initial: UnsafePointer<CChar>?,
    _ out: UnsafeMutablePointer<CChar>?,
    _ outLen: Int
) -> Int32 {
    guard let out, outLen > 0 else { return 0 }
    let t = title.map { String(cString: $0) } ?? ""
    let m = message.map { String(cString: $0) } ?? ""
    let i = initial.map { String(cString: $0) } ?? ""
    return MainActor.assumeIsolated {
        MacNativeTextInput.prompt(title: t, message: m, initial: i, out: out, outLen: outLen)
    }
}

// MARK: - Change keyboard shortcut (1.10)

@_silgen_name("OpenRCT2MacNativeShortcutApplyChord")
func OpenRCT2MacNativeShortcutApplyChord(_ id: UnsafePointer<CChar>?, _ chord: UnsafePointer<CChar>?)

enum MacChangeShortcutAlert {
    @MainActor
    static func present(id: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Change Shortcut"
        alert.informativeText = "Press the new key combination, or click Remove."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "." {
                return event // allow cancel chord through
            }
            var parts: [String] = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.control) { parts.append("CTRL") }
            if flags.contains(.option) { parts.append("ALT") }
            if flags.contains(.shift) { parts.append("SHIFT") }
            if flags.contains(.command) { parts.append("GUI") }
            if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
                parts.append(chars)
            }
            let chord = parts.joined(separator: "+")
            if !chord.isEmpty {
                OpenRCT2MacNativeShortcutApplyChord(id, chord)
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
                NSApp.abortModal()
            }
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        if response == .alertFirstButtonReturn {
            OpenRCT2MacNativeShortcutApplyChord(id, "")
        }
        return true
    }
}

@_cdecl("OpenRCT2MacNativeShortcutChangeShow")
func OpenRCT2MacNativeShortcutChangeShow(_ id: UnsafePointer<CChar>?) -> Bool {
    let sid = id.map { String(cString: $0) } ?? ""
    guard !sid.isEmpty else { return false }
    return MainActor.assumeIsolated { MacChangeShortcutAlert.present(id: sid) }
}
