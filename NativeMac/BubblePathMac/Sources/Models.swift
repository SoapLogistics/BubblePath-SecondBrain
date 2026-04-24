import Foundation

struct BubblePathDocument: Codable {
    var app: String?
    var version: Int
    var selectedId: UUID?
    var bubbles: [Bubble]
    var savedAt: Date?
}

struct Bubble: Codable, Identifiable, Equatable {
    var id: UUID
    var type: BubbleType
    var title: String?
    var bodyText: String?
    var content: String
    var createdAt: Date
    var updatedAt: Date?
    var x: Double
    var y: Double
    var tags: [String]
    var memoryScope: BubbleMemoryScope
    var links: [UUID]
    var messages: [BubbleMessage]

    init(
        id: UUID = UUID(),
        type: BubbleType,
        title: String? = nil,
        bodyText: String? = nil,
        content: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        x: Double,
        y: Double,
        tags: [String] = [],
        memoryScope: BubbleMemoryScope = .shared,
        links: [UUID] = [],
        messages: [BubbleMessage] = []
    ) {
        let resolvedTitle = Self.clean(title) ?? Self.clean(content) ?? "Untitled bubble"
        let resolvedBody = Self.clean(bodyText)

        self.id = id
        self.type = type
        self.title = resolvedTitle
        self.bodyText = resolvedBody
        self.content = resolvedTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.x = x
        self.y = y
        self.tags = tags
        self.memoryScope = memoryScope
        self.links = links
        self.messages = messages
    }

    var displayTitle: String {
        Self.clean(title) ?? Self.clean(content) ?? "Untitled bubble"
    }

    var displayBody: String {
        Self.clean(bodyText) ?? ""
    }

    var lastEditedAt: Date {
        updatedAt ?? createdAt
    }

    var shortLabel: String {
        let trimmed = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled bubble" : trimmed
    }

    var captureSourceLabel: String? {
        if tags.contains("webpage") {
            return "Webpage"
        }
        if tags.contains("textselection") {
            return "Selection"
        }
        if tags.contains("chatexport") {
            return "Chat"
        }
        if tags.contains("note") && type == .file {
            return "Captured note"
        }
        if tags.contains("imagefile") {
            return "Image"
        }
        if tags.contains("audiofile") {
            return "Audio"
        }
        if tags.contains("videofile") {
            return "Video"
        }
        return nil
    }

    var captureSourceQuery: String? {
        if tags.contains("webpage") {
            return "webpage"
        }
        if tags.contains("textselection") {
            return "textselection"
        }
        if tags.contains("chatexport") {
            return "chatexport"
        }
        if tags.contains("note") && type == .file {
            return "note"
        }
        if tags.contains("imagefile") {
            return "imagefile"
        }
        if tags.contains("audiofile") {
            return "audiofile"
        }
        if tags.contains("videofile") {
            return "videofile"
        }
        return nil
    }

    var sourceURL: URL? {
        metadataValue(for: "Source URL").flatMap(URL.init(string:))
    }

    var sourceHostLabel: String? {
        sourceURL?.host(percentEncoded: false)?
            .replacingOccurrences(of: "www.", with: "")
    }

    var sourceFileURL: URL? {
        guard let sourceURL, sourceURL.isFileURL else { return nil }
        return sourceURL
    }

    var sourceFileLocationLabel: String? {
        sourceFileURL?.deletingLastPathComponent().lastPathComponent
    }

    var sourceAppLabel: String? {
        metadataValue(for: "Source app")
    }

    var sourceConversationLabel: String? {
        metadataValue(for: "Source conversation")
    }

    var sourceConversationIDLabel: String? {
        metadataValue(for: "Source conversation ID")
    }

    var sourceConversationSearchLabel: String? {
        sourceConversationLabel ?? sourceConversationIDLabel
    }

    var sourceFileLabels: [String] {
        displayBody
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let prefix = "Source file: "
                guard line.hasPrefix(prefix) else { return nil }
                return Self.clean(String(line.dropFirst(prefix.count)))
            }
    }

    var searchableText: String {
        [
            displayTitle,
            displayBody,
            type.label,
            sourceConversationSearchLabel ?? "",
            sourceConversationIDLabel ?? "",
            tags.joined(separator: " "),
            messages.map(\.text).joined(separator: " "),
            type.rawValue
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private func metadataValue(for key: String) -> String? {
        let prefix = "\(key): "
        guard let line = displayBody
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix(prefix) })
        else {
            return nil
        }

        return Self.clean(String(line.dropFirst(prefix.count)))
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case bodyText
        case content
        case createdAt
        case updatedAt
        case x
        case y
        case tags
        case memoryScope
        case links
        case messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let type = try container.decode(BubbleType.self, forKey: .type)
        let title = try container.decodeIfPresent(String.self, forKey: .title)
        let bodyText = try container.decodeIfPresent(String.self, forKey: .bodyText)
        let content = try container.decodeIfPresent(String.self, forKey: .content)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let memoryScope = try container.decodeIfPresent(BubbleMemoryScope.self, forKey: .memoryScope) ?? .shared
        let links = try container.decodeIfPresent([UUID].self, forKey: .links) ?? []
        let messages = try container.decodeIfPresent([BubbleMessage].self, forKey: .messages) ?? []

        self.init(
            id: id,
            type: type,
            title: title,
            bodyText: bodyText,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            x: x,
            y: y,
            tags: tags,
            memoryScope: memoryScope,
            links: links,
            messages: messages
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(bodyText, forKey: .bodyText)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(tags, forKey: .tags)
        try container.encode(memoryScope, forKey: .memoryScope)
        try container.encode(links, forKey: .links)
        try container.encode(messages, forKey: .messages)
    }
}

enum BubbleMemoryScope: String, Codable, CaseIterable, Identifiable {
    case shared
    case privateBubble = "private"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shared:
            return "Shared memory"
        case .privateBubble:
            return "Private bubble"
        }
    }

    var detail: String {
        switch self {
        case .shared:
            return "This bubble can draw from the wider BubblePath memory."
        case .privateBubble:
            return "This bubble stays inside its own writing and chat history."
        }
    }
}

enum BubbleType: String, Codable, CaseIterable, Identifiable {
    case thought
    case question
    case decision
    case seed
    case file
    case chat

    var id: String { rawValue }
}

struct BubbleMessage: Codable, Identifiable, Equatable {
    var id: UUID
    var role: BubbleMessageRole
    var text: String
    var createdAt: Date
    var model: String?
    var isPending: Bool?
}

enum BubbleMessageRole: String, Codable {
    case user
    case assistant
    case note
}

enum SearchMatchKind {
    case direct
    case related

    var label: String {
        switch self {
        case .direct:
            return "Direct match"
        case .related:
            return "Related"
        }
    }
}

struct BubbleSearchMatch: Identifiable {
    let bubble: Bubble
    let kind: SearchMatchKind
    let reason: String
    let snippet: String?

    var id: UUID { bubble.id }
}

struct BubbleSearchSnapshot {
    let query: String
    let displayQuery: String
    let direct: [BubbleSearchMatch]
    let related: [BubbleSearchMatch]
    let relatedTerms: [String]
    let isExactPhrase: Bool

    var visibleBubbles: [Bubble] {
        (direct + related).map(\.bubble)
    }

    var isActive: Bool {
        !query.isEmpty
    }
}

extension Bubble {
    static let starter = Bubble(
        type: .seed,
        title: "BubblePath",
        bodyText: "A calm place where conversation becomes creation.",
        x: 42,
        y: 40,
        links: [],
        messages: [
            BubbleMessage(
                id: UUID(),
                role: .note,
                text: "The first native Mac version should protect the local vault first.",
                createdAt: Date(),
                model: nil,
                isPending: nil
            )
        ]
    )
}
