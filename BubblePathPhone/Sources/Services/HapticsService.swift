import Foundation

#if os(iOS)
import UIKit
#endif

enum HapticsService {
    static func bubbleCreated() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func bubbleTapped() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    static func bubbleOpened() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        #endif
    }
}
