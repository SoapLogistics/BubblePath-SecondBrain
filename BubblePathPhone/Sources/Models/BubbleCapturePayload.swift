import Foundation

struct BubbleCapturePayload: Codable {
    var sourceType: BubbleCaptureSourceType
    var sourceTitle: String
    var sourceURL: URL?
    var capturedText: String
    var capturedAt: Date
    var suggestedBubbleTitle: String
    var targetBubbleID: UUID?
    var sourceApp: String?

    var resolvedTitle: String {
        let suggested = suggestedBubbleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !suggested.isEmpty {
            return suggested
        }

        let source = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return source
        }

        return "Captured bubble"
    }

    var resolvedBody: String {
        var parts: [String] = []

        parts.append("Source type: \(sourceType.label)")
        parts.append("Captured at: \(Self.captureFormatter.string(from: capturedAt))")

        let trimmedSourceTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSourceTitle.isEmpty {
            parts.append("Source title: \(trimmedSourceTitle)")
        }

        if let sourceApp, !sourceApp.isEmpty {
            parts.append("Source app: \(sourceApp)")
        }

        if let sourceURL {
            parts.append("Source URL: \(sourceURL.absoluteString)")
        }

        parts.append(capturedText.trimmingCharacters(in: .whitespacesAndNewlines))
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static let captureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum BubbleCaptureSourceType: String, Codable, CaseIterable, Identifiable {
    case webpage
    case textSelection
    case chatExport
    case note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .webpage:
            return "Webpage"
        case .textSelection:
            return "Text selection"
        case .chatExport:
            return "Chat export"
        case .note:
            return "Note"
        }
    }
}
