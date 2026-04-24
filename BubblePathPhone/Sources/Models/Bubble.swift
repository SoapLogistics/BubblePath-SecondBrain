import Foundation

struct Bubble: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    var sourceLabel: String?
    var createdAt: Date
    var updatedAt: Date
    var x: Double
    var y: Double
    var floatSeed: Double

    static func make(at point: CGPoint) -> Bubble {
        let now = Date()
        return Bubble(
            id: UUID(),
            title: "",
            body: "",
            sourceLabel: nil,
            createdAt: now,
            updatedAt: now,
            x: point.x,
            y: point.y,
            floatSeed: Double.random(in: 0...(Double.pi * 2))
        )
    }
}
