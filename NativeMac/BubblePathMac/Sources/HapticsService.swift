import AppKit

enum BubbleHaptic {
    case create
    case select
    case open
}

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private init() {}

    func perform(_ feedback: BubbleHaptic) {
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch feedback {
        case .create:
            pattern = .alignment
        case .select, .open:
            pattern = .levelChange
        }

        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
