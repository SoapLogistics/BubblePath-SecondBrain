import SwiftUI

struct BubbleStyle {
    let backgroundTint: Color
    let borderColor: Color
    let accentColor: Color
    let iconName: String
    let glowColor: Color
}

extension BubbleType {
    var label: String {
        switch self {
        case .thought:
            return "Idea"
        case .question:
            return "Question"
        case .decision:
            return "Decision"
        case .seed:
            return "Core Truth"
        case .file:
            return "Reference"
        case .chat:
            return "AI Chat"
        }
    }

    var bubbleStyle: BubbleStyle {
        switch self {
        case .thought:
            return BubbleStyle(
                backgroundTint: Color(red: 0.63, green: 0.79, blue: 0.97),
                borderColor: Color(red: 0.36, green: 0.56, blue: 0.82),
                accentColor: Color(red: 0.26, green: 0.46, blue: 0.76),
                iconName: "lightbulb",
                glowColor: Color(red: 0.63, green: 0.79, blue: 0.97)
            )
        case .question:
            return BubbleStyle(
                backgroundTint: Color(red: 0.73, green: 0.70, blue: 0.96),
                borderColor: Color(red: 0.47, green: 0.43, blue: 0.79),
                accentColor: Color(red: 0.38, green: 0.34, blue: 0.71),
                iconName: "questionmark.circle",
                glowColor: Color(red: 0.73, green: 0.70, blue: 0.96)
            )
        case .decision:
            return BubbleStyle(
                backgroundTint: Color(red: 0.72, green: 0.91, blue: 0.70),
                borderColor: Color(red: 0.34, green: 0.63, blue: 0.32),
                accentColor: Color(red: 0.22, green: 0.51, blue: 0.22),
                iconName: "checkmark.circle",
                glowColor: Color(red: 0.72, green: 0.91, blue: 0.70)
            )
        case .seed:
            return BubbleStyle(
                backgroundTint: Color(red: 0.96, green: 0.84, blue: 0.49),
                borderColor: Color(red: 0.76, green: 0.58, blue: 0.14),
                accentColor: Color(red: 0.66, green: 0.48, blue: 0.08),
                iconName: "sparkles",
                glowColor: Color(red: 0.98, green: 0.86, blue: 0.44)
            )
        case .file:
            return BubbleStyle(
                backgroundTint: Color(red: 0.82, green: 0.84, blue: 0.88),
                borderColor: Color(red: 0.50, green: 0.54, blue: 0.61),
                accentColor: Color(red: 0.39, green: 0.43, blue: 0.50),
                iconName: "book",
                glowColor: Color(red: 0.82, green: 0.84, blue: 0.88)
            )
        case .chat:
            return BubbleStyle(
                backgroundTint: Color(red: 0.55, green: 0.86, blue: 0.83),
                borderColor: Color(red: 0.22, green: 0.61, blue: 0.58),
                accentColor: Color(red: 0.14, green: 0.48, blue: 0.46),
                iconName: "bubble.left.and.bubble.right",
                glowColor: Color(red: 0.55, green: 0.86, blue: 0.83)
            )
        }
    }
}
