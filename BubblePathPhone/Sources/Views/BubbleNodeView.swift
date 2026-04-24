import SwiftUI

struct BubbleNodeView: View {
    let bubble: Bubble
    let title: String
    let subtitle: String
    let timestamp: Date

    var body: some View {
        let pulse = 1.0 + sin(timestamp.timeIntervalSinceReferenceDate * 0.9 + bubble.floatSeed) * 0.012

        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.25))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.34, green: 0.40, blue: 0.46))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(18)
        .frame(width: 132, height: 132)
        .background(
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.86),
                            Color.white.opacity(0.56)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.75), lineWidth: 1.0)
        )
        .background(
            Circle()
                .fill(Color(red: 0.72, green: 0.86, blue: 0.94).opacity(0.18))
                .blur(radius: 18)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        .scaleEffect(pulse)
        .animation(.easeInOut(duration: 0.32), value: title)
    }
}
