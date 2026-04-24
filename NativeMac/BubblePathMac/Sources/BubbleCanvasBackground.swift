import SwiftUI

struct BubbleCanvasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 0.95),
                    Color(red: 0.97, green: 0.96, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: -20, y: size.height * 0.16))
                path.addCurve(
                    to: CGPoint(x: size.width + 20, y: size.height * 0.28),
                    control1: CGPoint(x: size.width * 0.24, y: size.height * 0.08),
                    control2: CGPoint(x: size.width * 0.68, y: size.height * 0.36)
                )
                path.move(to: CGPoint(x: -20, y: size.height * 0.74))
                path.addCurve(
                    to: CGPoint(x: size.width + 40, y: size.height * 0.62),
                    control1: CGPoint(x: size.width * 0.28, y: size.height * 0.82),
                    control2: CGPoint(x: size.width * 0.72, y: size.height * 0.54)
                )
                context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1.1)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear, Color.black.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}
