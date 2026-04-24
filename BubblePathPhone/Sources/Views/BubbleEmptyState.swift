import SwiftUI

struct BubbleEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Tap the quiet space")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.13, green: 0.18, blue: 0.24))
            Text("A thought can begin anywhere.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }
}
