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
