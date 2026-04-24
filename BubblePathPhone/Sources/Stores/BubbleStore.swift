import Foundation
import SwiftUI

@MainActor
final class BubbleStore: ObservableObject {
    @Published private(set) var bubbles: [Bubble] = []
    @Published var selectedBubbleID: UUID?
    @Published var statusText = "Loading bubbles..."
    @Published var lastSavedAt: Date?

    private let persistence = BubblePersistence()

    var selectedBubble: Bubble? {
        guard let selectedBubbleID else { return nil }
        return bubbles.first(where: { $0.id == selectedBubbleID })
    }

    func load() async {
        do {
            bubbles = try persistence.load()
            lastSavedAt = try persistence.lastSavedAt()
            statusText = bubbles.isEmpty ? "Tap empty space to create your first bubble." : "Loaded \(bubbles.count) bubbles."
        } catch {
            statusText = "Could not load bubbles: \(error.localizedDescription)"
        }
    }

    func createBubble(at normalizedPoint: CGPoint) {
        let bubble = Bubble.make(at: normalizedPoint)
        bubbles.append(bubble)
        selectedBubbleID = bubble.id
        persist("Created a new bubble.")
        HapticsService.bubbleCreated()
        HapticsService.bubbleOpened()
    }

    func openBubble(_ bubble: Bubble) {
        selectedBubbleID = bubble.id
        HapticsService.bubbleTapped()
        HapticsService.bubbleOpened()
    }

    func closeBubble() {
        selectedBubbleID = nil
    }

    func updateBubble(id: UUID, title: String, body: String) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].title = title
        bubbles[index].body = body
        bubbles[index].updatedAt = Date()
        persist("Saved bubble changes.")
    }

    func importCapture(_ payload: BubbleCapturePayload) {
        if let targetBubbleID = payload.targetBubbleID,
           let index = bubbles.firstIndex(where: { $0.id == targetBubbleID }) {
            let appended = [bubbles[index].body.trimmingCharacters(in: .whitespacesAndNewlines), payload.resolvedBody]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n---\n\n")
            bubbles[index].body = appended
            bubbles[index].updatedAt = Date()
            selectedBubbleID = bubbles[index].id
            persist("Added captured material to an existing bubble.")
            return
        }

        var bubble = Bubble.make(at: CGPoint(x: 0.5, y: 0.5))
        bubble.title = payload.resolvedTitle
        bubble.body = payload.resolvedBody
        bubble.sourceLabel = payload.sourceType.label
        bubble.updatedAt = Date()
        bubbles.insert(bubble, at: 0)
        selectedBubbleID = bubble.id
        persist("Captured a new bubble from \(payload.sourceType.rawValue).")
    }

    func repositionBubble(id: UUID, normalizedPoint: CGPoint) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].x = clamp(normalizedPoint.x)
        bubbles[index].y = clamp(normalizedPoint.y)
        bubbles[index].updatedAt = Date()
        persist("Moved bubble.")
    }

    func title(for bubble: Bubble) -> String {
        let trimmed = bubble.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let body = bubble.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return String(body.prefix(22)) }
        return "Untitled"
    }

    func subtitle(for bubble: Bubble) -> String {
        if let sourceLabel = bubble.sourceLabel, !sourceLabel.isEmpty {
            return sourceLabel
        }
        let body = bubble.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return String(body.prefix(34)) }
        return bubble.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func persist(_ message: String) {
        do {
            try persistence.save(bubbles)
            lastSavedAt = Date()
            statusText = message
        } catch {
            statusText = "Could not save bubbles: \(error.localizedDescription)"
        }
    }

    private func clamp(_ value: CGFloat) -> Double {
        Double(min(max(value, 0.08), 0.92))
    }
}
