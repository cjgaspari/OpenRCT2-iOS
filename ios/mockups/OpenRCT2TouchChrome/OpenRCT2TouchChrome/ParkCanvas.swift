import SwiftUI

struct ParkCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.68, blue: 0.34),
                Color(red: 0.14, green: 0.48, blue: 0.52),
                Color(red: 0.18, green: 0.36, blue: 0.78),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.10))
                        .frame(width: size.width * 0.72)
                        .offset(x: size.width * 0.08, y: size.height * 0.18)
                    Circle()
                        .fill(.green.opacity(0.18))
                        .frame(width: size.width * 0.42)
                        .offset(x: -size.width * 0.18, y: size.height * 0.08)
                    Circle()
                        .fill(.cyan.opacity(0.16))
                        .frame(width: size.width * 0.55)
                        .offset(x: size.width * 0.22, y: -size.height * 0.12)
                }
                .blur(radius: 8)
            }
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

struct EngineWindowCard: View {
    let title: String
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close window")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.73, green: 0.13, blue: 0.13))

            Text("Existing in-engine window. Native chrome only opens this intent — it does not rebuild the picker.")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.8))
                .padding(12)
        }
        .frame(maxWidth: 300)
        .background(Color(red: 0.94, green: 0.91, blue: 0.80))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
    }
}
