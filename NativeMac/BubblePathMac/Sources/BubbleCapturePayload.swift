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
    var suggestedTags: [String]?
    var suggestedType: BubbleType?

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

    var sourceConversationLabel: String? {
        metadataValue(for: "Source conversation") ?? {
            guard sourceType == .chatExport else { return nil }
            let trimmedSourceTitle = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedSourceTitle.isEmpty ? nil : trimmedSourceTitle
        }()
    }

    var sourceConversationIDLabel: String? {
        metadataValue(for: "Source conversation ID")
    }

    private func metadataValue(for key: String) -> String? {
        let prefix = "\(key): "
        guard let line = capturedText
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix(prefix) })
        else {
            return nil
        }

        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static let captureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct BubbleCaptureImportEnvelope: Codable {
    var app = "BubblePath"
    var kind = "capture-batch"
    var version = 1
    var captures: [BubbleCapturePayload]
    var sourceApp: String?
    var targetBubbleID: UUID?
    var sourceTitle: String?
    var sourceURL: URL?

    var resolvedCaptures: [BubbleCapturePayload] {
        captures.map { payload in
            var resolved = payload

            if let sourceApp, (resolved.sourceApp ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolved.sourceApp = sourceApp
            }

            if let targetBubbleID, resolved.targetBubbleID == nil {
                resolved.targetBubbleID = targetBubbleID
            }

            if let sourceTitle, resolved.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolved.sourceTitle = sourceTitle
            }

            if let sourceURL, resolved.sourceURL == nil {
                resolved.sourceURL = sourceURL
            }

            return resolved
        }
    }
}

struct BubbleChatImportEntry: Codable {
    var bubbleTitle: String
    var excerpt: String
    var tags: [String]?
    var bubbleType: BubbleType?
    var sourceChatTitle: String?
    var sourceChatID: String?
    var sourceURL: URL?
    var capturedAt: Date?

    func resolvedCapture(defaultSourceApp: String) -> BubbleCapturePayload {
        let chatTitle = sourceChatTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatID = sourceChatID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSourceTitle = (chatTitle?.isEmpty == false ? chatTitle : nil) ?? bubbleTitle

        var parts: [String] = []
        if let chatTitle, !chatTitle.isEmpty {
            parts.append("Source conversation: \(chatTitle)")
        }
        if let chatID, !chatID.isEmpty {
            parts.append("Source conversation ID: \(chatID)")
        }
        parts.append(excerpt.trimmingCharacters(in: .whitespacesAndNewlines))

        return BubbleCapturePayload(
            sourceType: .chatExport,
            sourceTitle: resolvedSourceTitle,
            sourceURL: sourceURL,
            capturedText: parts.filter { !$0.isEmpty }.joined(separator: "\n\n"),
            capturedAt: capturedAt ?? Date(),
            suggestedBubbleTitle: bubbleTitle,
            targetBubbleID: nil,
            sourceApp: defaultSourceApp,
            suggestedTags: tags,
            suggestedType: bubbleType
        )
    }
}

struct BubbleChatImportEnvelope: Codable {
    var app = "BubblePath"
    var kind = "chat-history-batch"
    var version = 1
    var sourceApp: String?
    var sourceChatTitle: String?
    var sourceChatID: String?
    var sourceURL: URL?
    var chats: [BubbleChatImportEntry]

    var resolvedCaptures: [BubbleCapturePayload] {
        let trimmedSourceApp = sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackSourceApp = trimmedSourceApp.isEmpty ? "ChatGPT History Import" : trimmedSourceApp

        return chats.map { entry in
            var resolved = entry.resolvedCapture(defaultSourceApp: fallbackSourceApp)

            if let sourceURL, resolved.sourceURL == nil {
                resolved.sourceURL = sourceURL
            }

            if let sourceChatTitle,
               resolved.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolved.sourceTitle = sourceChatTitle
            }

            if let sourceChatTitle {
                let trimmedSourceChatTitle = sourceChatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let chatTitleLine = "Source conversation: \(trimmedSourceChatTitle)"
                if !trimmedSourceChatTitle.isEmpty, !resolved.capturedText.contains(chatTitleLine) {
                    resolved.capturedText = chatTitleLine + "\n\n" + resolved.capturedText
                }
            }

            if let sourceChatID, !sourceChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let chatIDLine = "Source conversation ID: \(sourceChatID)"
                if !resolved.capturedText.contains(chatIDLine) {
                    resolved.capturedText = chatIDLine + "\n\n" + resolved.capturedText
                }
            }

            return resolved
        }
    }
}

struct BubbleLooseChatImportEnvelope: Codable {
    var sourceApp: String?
    var sourceChatTitle: String?
    var sourceChatID: String?
    var sourceURL: URL?
    var chats: [BubbleChatImportEntry]

    var resolvedCaptures: [BubbleCapturePayload] {
        BubbleChatImportEnvelope(
            app: "BubblePath",
            kind: "chat-history-batch",
            version: 1,
            sourceApp: sourceApp,
            sourceChatTitle: sourceChatTitle,
            sourceChatID: sourceChatID,
            sourceURL: sourceURL,
            chats: chats
        )
        .resolvedCaptures
    }
}

enum BubbleCaptureSourceType: String, Codable, CaseIterable, Identifiable {
    case webpage
    case textSelection
    case chatExport
    case note
    case imageFile
    case audioFile
    case videoFile

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
        case .imageFile:
            return "Image file"
        case .audioFile:
            return "Audio file"
        case .videoFile:
            return "Video file"
        }
    }
}
