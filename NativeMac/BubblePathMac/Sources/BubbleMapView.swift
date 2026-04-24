import SwiftUI

struct BubbleMapView: View {
    @EnvironmentObject private var store: BubbleStore

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                let snapshot = store.searchSnapshot(limit: max(store.bubbles.count, 12))
                let visibleBubbles = snapshot.isActive ? snapshot.visibleBubbles : store.bubbles
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    HapticsService.shared.perform(.create)
                                    store.createBubble(at: value.location, in: proxy.size)
                                }
                        )

                    Canvas { context, _ in
                        drawLinks(
                            context: context,
                            canvasSize: proxy.size,
                            now: timeline.date,
                            visibleBubbles: visibleBubbles
                        )
                    }

                    ForEach(visibleBubbles) { bubble in
                        let anchor = anchorPoint(for: bubble, in: proxy.size)
                        let offset = floatingOffset(for: bubble, now: timeline.date)
                        let position = CGPoint(x: anchor.x + offset.width, y: anchor.y + offset.height)

                        BubbleNodeView(
                            bubble: bubble,
                            isSelected: bubble.id == store.selectedId,
                            searchKind: store.searchMatchKind(for: bubble)
                        )
                        .position(position)
                        .highPriorityGesture(
                            SpatialTapGesture()
                                .onEnded { _ in
                                    HapticsService.shared.perform(bubble.id == store.selectedId ? .open : .select)
                                    store.select(bubble.id)
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let x = ((value.location.x - offset.width) / max(proxy.size.width, 1)) * 100
                                    let y = ((value.location.y - offset.height) / max(proxy.size.height, 1)) * 100
                                    store.updatePosition(for: bubble.id, x: x, y: y)
                                }
                        )
                    }
                }
            }
        }
    }

    private func drawLinks(context: GraphicsContext, canvasSize: CGSize, now: Date, visibleBubbles: [Bubble]) {
        var drawn = Set<String>()
        let visibleIds = Set(visibleBubbles.map(\.id))

        for bubble in visibleBubbles {
            for linkedId in bubble.links {
                guard visibleIds.contains(linkedId) else { continue }
                guard let linked = store.bubbles.first(where: { $0.id == linkedId }) else { continue }
                let key = [bubble.id.uuidString, linked.id.uuidString].sorted().joined(separator: ":")
                guard !drawn.contains(key) else { continue }
                drawn.insert(key)

                let start = offsetPoint(for: bubble, in: canvasSize, now: now)
                let end = offsetPoint(for: linked, in: canvasSize, now: now)
                let midX = (start.x + end.x) / 2

                var path = Path()
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: midX, y: start.y),
                    control2: CGPoint(x: midX, y: end.y)
                )

                context.stroke(
                    path,
                    with: .color(Color(red: 0.24, green: 0.38, blue: 0.40).opacity(0.18)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8])
                )
            }
        }
    }

    private func offsetPoint(for bubble: Bubble, in size: CGSize, now: Date) -> CGPoint {
        let anchor = anchorPoint(for: bubble, in: size)
        let drift = floatingOffset(for: bubble, now: now)
        return CGPoint(x: anchor.x + drift.width, y: anchor.y + drift.height)
    }

    private func anchorPoint(for bubble: Bubble, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (bubble.x / 100) * size.width,
            y: (bubble.y / 100) * size.height
        )
    }

    private func floatingOffset(for bubble: Bubble, now: Date) -> CGSize {
        let time = now.timeIntervalSinceReferenceDate
        let seed = bubble.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let phase = Double(seed % 360) * .pi / 180
        let amplitude = CGFloat(5 + (seed % 5))

        return CGSize(
            width: CGFloat(sin(time * 0.22 + phase) * Double(amplitude)),
            height: CGFloat(cos(time * 0.18 + phase * 0.8) * Double(amplitude * 0.7))
        )
    }
}

private struct BubbleNodeView: View {
    let bubble: Bubble
    let isSelected: Bool
    let searchKind: SearchMatchKind?

    private var style: BubbleStyle {
        bubble.type.bubbleStyle
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(isSelected ? 0.28 : 0.18))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    style.backgroundTint.opacity(isSelected ? 0.50 : 0.36),
                                    Color.white.opacity(isSelected ? 0.30 : 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Circle()
                .strokeBorder(isSelected ? style.borderColor.opacity(0.90) : Color.white.opacity(0.40), lineWidth: isSelected ? 2.4 : 1.1)

            if let searchKind {
                Circle()
                    .strokeBorder(searchStroke(for: searchKind), lineWidth: searchKind == .direct ? 3 : 2)
                    .padding(searchKind == .direct ? 2 : 4)
            }

            VStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .font(.system(size: isSelected ? 16 : 14, weight: .semibold))
                    .foregroundStyle(style.accentColor)
                    .frame(width: 20, height: 20)

                Text(bubble.shortLabel)
                    .font(.system(size: isSelected ? 14 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }
        }
        .frame(width: isSelected ? 148 : 126, height: isSelected ? 148 : 126)
        .shadow(color: style.glowColor.opacity(isSelected ? 0.26 : (bubble.type == .seed ? 0.20 : 0.10)), radius: isSelected ? 26 : (bubble.type == .seed ? 20 : 16), y: 10)
        .shadow(color: .white.opacity(0.4), radius: 8, y: -2)
        .scaleEffect(isSelected ? 1.04 : (bubble.type == .seed ? 1.02 : 1))
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: bubble.type)
    }

    private func searchStroke(for kind: SearchMatchKind) -> Color {
        switch kind {
        case .direct:
            return Color(red: 0.31, green: 0.59, blue: 0.69).opacity(0.86)
        case .related:
            return Color(red: 0.73, green: 0.64, blue: 0.36).opacity(0.72)
        }
    }
}
