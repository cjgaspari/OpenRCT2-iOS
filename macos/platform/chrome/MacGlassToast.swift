/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * CJ HIG lock: news + errors = bottom-center Liquid Glass toast (choices 2A/3A).
 * Functional chrome layer only — not content-window glass.
 *****************************************************************************/

import SwiftUI

enum MacToastKind: Equatable {
    case news
    case error
}

struct MacGlassToastBar: View {
    let kind: MacToastKind
    let message: String
    let showSubject: Bool
    let showLocate: Bool
    let onSubject: () -> Void
    let onLocate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "megaphone.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(kind == .error ? Color.orange : Color.primary)
            Text(message)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: 420, alignment: .leading)
            if showSubject {
                Button(action: onSubject) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Show subject")
            }
            if showLocate {
                Button(action: onLocate) {
                    Image(systemName: "location.viewfinder")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Locate subject")
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.22), in: Capsule())
        .glassEffect(
            kind == .error
                ? GlassChrome.statusPlate(tint: .orange, opacity: 0.28)
                : GlassChrome.statusPlate(tint: GlassChrome.session, opacity: 0.30),
            in: .capsule
        )
        .accessibilityIdentifier("openrct2.mac.toast")
    }
}
