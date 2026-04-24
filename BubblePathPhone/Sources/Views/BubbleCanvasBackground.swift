import SwiftUI

struct BubbleCanvasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.98, green: 0.98, blue: 0.97),
                    Color(red: 0.94, green: 0.97, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.7),
                    Color.white.opacity(0.0)
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 380
            )

            RadialGradient(
                colors: [
                    Color(red: 0.69, green: 0.84, blue: 0.95).opacity(0.15),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}
