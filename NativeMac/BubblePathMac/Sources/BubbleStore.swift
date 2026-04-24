import Combine
import CoreGraphics
import Foundation

@MainActor
final class BubbleStore: ObservableObject {
    struct BackupInfo {
        var regularCount = 0
        var preRestoreCount = 0
        var maxRegularCount = 24
        var maxPreRestoreCount = 12
    }

    private struct CaptureImportOutcome {
        var appendedBubbleID: UUID?
        var createdBubbleID: UUID?
    }

    @Published var bubbles: [Bubble] = []
    @Published var selectedId: UUID?
    @Published var statusText = "Loading local vault..."
    @Published var vaultURL = BubbleStore.defaultVaultURL()
    @Published var backupInfo = BackupInfo()
    @Published var lastSavedAt: Date?
    @Published private(set) var hasPendingAutosave = false
    @Published var searchQuery = ""
    @Published private(set) var recentSearches: [String]

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let searchHistoryKey = "BubblePathMac.recentSearches"
    private var cancellables: Set<AnyCancellable> = []
    private var autosaveTask: Task<Void, Never>?

    init() {
        encoder = .bubblePathEncoder
        decoder = .bubblePathDecoder
        recentSearches = UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? []

        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.rememberSearchQueryIfNeeded()
            }
            .store(in: &cancellables)
    }

    var selectedBubble: Bubble? {
        guard let selectedId else { return bubbles.first }
        return bubbles.first { $0.id == selectedId }
    }

    var usingSharedProjectVault: Bool {
        vaultURL.standardizedFileURL == Self.defaultVaultURL().standardizedFileURL
    }

    func load() async {
        do {
            let url = vaultURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                bubbles = [.starter]
                selectedId = bubbles.first?.id
                statusText = "Started a fresh local vault."
                try save()
                return
            }

            let data = try Data(contentsOf: url)
            let document = try decoder.decode(BubblePathDocument.self, from: data)
            bubbles = document.bubbles
            selectedId = document.selectedId ?? bubbles.first?.id
            lastSavedAt = document.savedAt
            refreshBackupInfo()
            statusText = "Loaded \(bubbles.count) bubble\(bubbles.count == 1 ? "" : "s") from the local vault."
        } catch {
            bubbles = [.starter]
            selectedId = bubbles.first?.id
            lastSavedAt = nil
            refreshBackupInfo()
            statusText = "Vault load failed: \(error.localizedDescription)"
        }
    }

    func save() throws {
        autosaveTask?.cancel()
        autosaveTask = nil
        hasPendingAutosave = false
        try writeVaultToDisk(statusPrefix: "Saved")
    }

    func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        hasPendingAutosave = false
        do {
            try writeVaultToDisk(statusPrefix: "Autosaved")
        } catch {
            statusText = "Autosave failed: \(error.localizedDescription)"
        }
    }

    private func scheduleAutosave(reason: String = "Autosaved") {
        autosaveTask?.cancel()
        hasPendingAutosave = true
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(900))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                do {
                    self.hasPendingAutosave = false
                    try self.writeVaultToDisk(statusPrefix: reason)
                } catch {
                    self.hasPendingAutosave = false
                    self.statusText = "Autosave failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func writeVaultToDisk(statusPrefix: String) throws {
        let url = vaultURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let document = BubblePathDocument(
            app: "BubblePath",
            version: 1,
            selectedId: selectedId,
            bubbles: bubbles,
            savedAt: Date()
        )
        let data = try encoder.encode(document)
        try data.write(to: url, options: [.atomic])
        lastSavedAt = document.savedAt
        refreshBackupInfo()
        statusText = "\(statusPrefix) \(bubbles.count) bubble\(bubbles.count == 1 ? "" : "s") to disk."
    }

    func createBubble(content: String, type: BubbleType) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        createBubble(
            title: trimmed,
            bodyText: "",
            type: type,
            x: Double.random(in: 28...68),
            y: Double.random(in: 28...68),
            linkToSelection: true
        )
    }

    func createBubble(at point: CGPoint, in size: CGSize, type: BubbleType = .thought) {
        guard size.width > 0, size.height > 0 else { return }

        let x = min(max((point.x / size.width) * 100, 6), 94)
        let y = min(max((point.y / size.height) * 100, 8), 90)

        createBubble(
            title: "New bubble",
            bodyText: "",
            type: type,
            x: x,
            y: y,
            linkToSelection: false
        )
    }

    func createBubbleAtCanvasCenter(type: BubbleType = .thought) {
        createBubble(
            title: "New bubble",
            bodyText: "",
            type: type,
            x: 50,
            y: 48,
            linkToSelection: false
        )
    }

    func duplicateSelectedBubble() {
        guard let bubble = selectedBubble else { return }

        let duplicate = Bubble(
            type: bubble.type,
            title: bubble.displayTitle,
            bodyText: bubble.displayBody,
            createdAt: Date(),
            updatedAt: Date(),
            x: min(bubble.x + 6, 92),
            y: min(bubble.y + 4, 90),
            tags: bubble.tags,
            memoryScope: bubble.memoryScope,
            links: bubble.links,
            messages: bubble.messages
        )

        bubbles.insert(duplicate, at: 0)
        selectedId = duplicate.id
        statusText = "Duplicated \(bubble.shortLabel)."
        scheduleAutosave()
    }

    func nudgeSelectedBubble(xDelta: Double, yDelta: Double) {
        guard let index = selectedIndex() else { return }

        let nextX = min(max(bubbles[index].x + xDelta, 2), 94)
        let nextY = min(max(bubbles[index].y + yDelta, 2), 90)
        guard nextX != bubbles[index].x || nextY != bubbles[index].y else { return }

        bubbles[index].x = nextX
        bubbles[index].y = nextY
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func selectNextBubble() {
        guard !bubbles.isEmpty else { return }
        guard let selectedId, let index = bubbles.firstIndex(where: { $0.id == selectedId }) else {
            self.selectedId = bubbles.first?.id
            scheduleAutosave()
            return
        }

        let nextIndex = (index + 1) % bubbles.count
        self.selectedId = bubbles[nextIndex].id
        scheduleAutosave()
    }

    func selectPreviousBubble() {
        guard !bubbles.isEmpty else { return }
        guard let selectedId, let index = bubbles.firstIndex(where: { $0.id == selectedId }) else {
            self.selectedId = bubbles.first?.id
            scheduleAutosave()
            return
        }

        let previousIndex = index == 0 ? bubbles.count - 1 : index - 1
        self.selectedId = bubbles[previousIndex].id
        scheduleAutosave()
    }

    func updateSelected(title: String) {
        guard let index = selectedIndex() else { return }
        let resolved = resolvedTitle(from: title)
        bubbles[index].title = resolved
        bubbles[index].content = resolved
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func updateSelectedBody(_ bodyText: String) {
        guard let index = selectedIndex() else { return }
        bubbles[index].bodyText = bodyText
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func updateSelectedType(_ type: BubbleType) {
        guard let index = selectedIndex() else { return }
        bubbles[index].type = type
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func updateSelectedMemoryScope(_ scope: BubbleMemoryScope) {
        guard let index = selectedIndex() else { return }
        bubbles[index].memoryScope = scope
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func updateSelectedTags(from rawTags: String) {
        guard let index = selectedIndex() else { return }
        bubbles[index].tags = parseTags(from: rawTags)
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func addSelectedTag(_ tag: String) {
        guard let index = selectedIndex() else { return }
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        if !bubbles[index].tags.contains(normalized) {
            bubbles[index].tags.append(normalized)
            bubbles[index].tags.sort()
            bubbles[index].updatedAt = Date()
            scheduleAutosave()
        }
    }

    func updateSelected(content: String) {
        updateSelected(title: content)
    }

    func addMessage(text: String, role: BubbleMessageRole = .note, model: String? = nil) {
        guard let index = selectedIndex() else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        bubbles[index].messages.append(
            BubbleMessage(
                id: UUID(),
                role: role,
                text: trimmed,
                createdAt: Date(),
                model: model,
                isPending: nil
            )
        )
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func addPendingAssistantMessage() -> UUID? {
        guard let index = selectedIndex() else { return nil }
        let message = BubbleMessage(
            id: UUID(),
            role: .assistant,
            text: "Thinking...",
            createdAt: Date(),
            model: nil,
            isPending: true
        )
        bubbles[index].messages.append(message)
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
        return message.id
    }

    func resolvePendingAssistantMessage(id: UUID, text: String, model: String? = nil) {
        guard
            let bubbleIndex = selectedIndex(),
            let messageIndex = bubbles[bubbleIndex].messages.firstIndex(where: { $0.id == id })
        else { return }

        bubbles[bubbleIndex].messages[messageIndex].text = text
        bubbles[bubbleIndex].messages[messageIndex].model = model
        bubbles[bubbleIndex].messages[messageIndex].isPending = false
        bubbles[bubbleIndex].messages[messageIndex].createdAt = Date()
        bubbles[bubbleIndex].updatedAt = Date()
        scheduleAutosave()
    }

    func linkSelected(to targetId: UUID) {
        guard
            let selectedId,
            selectedId != targetId,
            let sourceIndex = bubbles.firstIndex(where: { $0.id == selectedId }),
            let targetIndex = bubbles.firstIndex(where: { $0.id == targetId })
        else { return }

        if !bubbles[sourceIndex].links.contains(targetId) {
            bubbles[sourceIndex].links.append(targetId)
        }
        if !bubbles[targetIndex].links.contains(selectedId) {
            bubbles[targetIndex].links.append(selectedId)
        }
        bubbles[sourceIndex].updatedAt = Date()
        bubbles[targetIndex].updatedAt = Date()
        scheduleAutosave()
    }

    func unlinkSelected(from targetId: UUID) {
        guard
            let selectedId,
            let sourceIndex = bubbles.firstIndex(where: { $0.id == selectedId }),
            let targetIndex = bubbles.firstIndex(where: { $0.id == targetId })
        else { return }

        bubbles[sourceIndex].links.removeAll { $0 == targetId }
        bubbles[targetIndex].links.removeAll { $0 == selectedId }
        bubbles[sourceIndex].updatedAt = Date()
        bubbles[targetIndex].updatedAt = Date()
        scheduleAutosave()
    }

    func updatePosition(for id: UUID, x: Double, y: Double) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].x = min(max(x, 2), 90)
        bubbles[index].y = min(max(y, 2), 88)
        bubbles[index].updatedAt = Date()
        scheduleAutosave()
    }

    func select(_ id: UUID) {
        selectedId = id
        scheduleAutosave()
    }

    func clearSelection() {
        guard selectedId != nil else { return }
        selectedId = nil
        scheduleAutosave()
    }

    func clearSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searchQuery = ""
        statusText = "Cleared search."
    }

    func deleteSelectedBubble() {
        guard let selectedId else { return }
        guard let index = bubbles.firstIndex(where: { $0.id == selectedId }) else {
            self.selectedId = bubbles.first?.id
            return
        }

        let removedBubble = bubbles.remove(at: index)

        if !removedBubble.links.isEmpty {
            for linkedID in removedBubble.links {
                guard let linkedIndex = bubbles.firstIndex(where: { $0.id == linkedID }) else { continue }
                bubbles[linkedIndex].links.removeAll { $0 == removedBubble.id }
                bubbles[linkedIndex].updatedAt = Date()
            }
        }

        if bubbles.isEmpty {
            self.selectedId = nil
        } else if index < bubbles.count {
            self.selectedId = bubbles[index].id
        } else {
            self.selectedId = bubbles[bubbles.count - 1].id
        }

        statusText = "Deleted \(removedBubble.shortLabel)."
        scheduleAutosave()
    }

    func reloadFromDisk() {
        Task {
            await load()
        }
    }

    func useSharedProjectVault() {
        vaultURL = Self.defaultVaultURL()
        statusText = "Switched back to the shared project vault."
        reloadFromDisk()
    }

    func refreshBackupInfo() {
        let dir = Self.backupsDirectoryURL()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            backupInfo = BackupInfo()
            return
        }

        let jsonNames = names.filter { $0.hasSuffix(".json") }
        backupInfo = BackupInfo(
            regularCount: jsonNames.filter { !$0.hasPrefix("pre-restore-") }.count,
            preRestoreCount: jsonNames.filter { $0.hasPrefix("pre-restore-") }.count,
            maxRegularCount: 24,
            maxPreRestoreCount: 12
        )
    }

    func currentDocument() -> BubblePathDocument {
        BubblePathDocument(
            app: "BubblePath",
            version: 1,
            selectedId: selectedId,
            bubbles: bubbles,
            savedAt: Date()
        )
    }

    func importDocument(_ document: BubblePathDocument, from sourceURL: URL? = nil) {
        if let sourceURL {
            vaultURL = sourceURL
        }
        bubbles = document.bubbles
        selectedId = document.selectedId ?? document.bubbles.first?.id
        lastSavedAt = document.savedAt
        statusText = "Imported \(bubbles.count) bubble\(bubbles.count == 1 ? "" : "s") from JSON."
        try? save()
    }

    func importCapture(_ payload: BubbleCapturePayload) {
        _ = applyCapture(payload)
        try? save()
    }

    func importCaptures(_ payloads: [BubbleCapturePayload]) {
        guard !payloads.isEmpty else {
            statusText = "No captures found in that JSON import."
            return
        }

        let outcomes = payloads.map { applyCapture($0) }

        let createdCount = outcomes.filter { $0.createdBubbleID != nil }.count
        let appendedCount = outcomes.filter { $0.appendedBubbleID != nil }.count
        let sharedSourceApp = sharedSourceApp(for: payloads)
        let sourceSuffix = sharedSourceApp.map { " from \($0)" } ?? ""
        let conversationSuffix = chatConversationImportSuffix(for: payloads)
        let appendedBubbleIDs = outcomes.compactMap(\.appendedBubbleID)
        let sharedTargetBubble = sharedTargetBubble(for: appendedBubbleIDs)
        let targetSuffix = sharedTargetBubble.map { " into \($0.shortLabel)" } ?? " into existing bubbles"

        switch (createdCount, appendedCount) {
        case (_, 0):
            statusText = "Imported \(createdCount) captured bubble\(createdCount == 1 ? "" : "s")\(sourceSuffix)\(conversationSuffix) from JSON."
        case (0, _):
            statusText = "Appended \(appendedCount) capture\(appendedCount == 1 ? "" : "s")\(sourceSuffix)\(conversationSuffix)\(targetSuffix)."
        default:
            statusText = "Imported \(createdCount) new capture\(createdCount == 1 ? "" : "s")\(sourceSuffix)\(conversationSuffix) and appended \(appendedCount)\(targetSuffix)."
        }

        try? save()
    }

    @discardableResult
    private func applyCapture(_ payload: BubbleCapturePayload) -> CaptureImportOutcome {
        let sourceLabel = payload.sourceType.label.lowercased()

        if let targetBubbleID = payload.targetBubbleID,
           let index = bubbles.firstIndex(where: { $0.id == targetBubbleID }) {
            let appended = [bubbles[index].displayBody, payload.resolvedBody]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n---\n\n")
            bubbles[index].bodyText = appended
            bubbles[index].updatedAt = Date()
            selectedId = bubbles[index].id
            statusText = "Added \(sourceLabel) material to \(bubbles[index].shortLabel)."
            return CaptureImportOutcome(appendedBubbleID: bubbles[index].id, createdBubbleID: nil)
        }

        let captureBubble = Bubble(
            type: payload.suggestedType ?? (payload.sourceType == .chatExport ? .chat : .file),
            title: payload.resolvedTitle,
            bodyText: payload.resolvedBody,
            x: Double.random(in: 24...76),
            y: Double.random(in: 22...74),
            tags: suggestedTags(for: payload),
            links: selectedId.map { [$0] } ?? [],
            messages: []
        )

        bubbles.insert(captureBubble, at: 0)
        selectedId = captureBubble.id
        statusText = "Captured a new \(sourceLabel) bubble as \(captureBubble.shortLabel)."
        return CaptureImportOutcome(appendedBubbleID: nil, createdBubbleID: captureBubble.id)
    }

    func searchResults(limit: Int = 8) -> [Bubble] {
        Array(searchSnapshot(limit: limit).direct.prefix(limit).map(\.bubble))
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        UserDefaults.standard.set(recentSearches, forKey: searchHistoryKey)
    }

    func recentBubbles(limit: Int = 8) -> [Bubble] {
        Array(
            bubbles
                .sorted { $0.lastEditedAt > $1.lastEditedAt }
                .prefix(limit)
        )
    }

    func recentCapturedBubbles(limit: Int = 6) -> [Bubble] {
        Array(
            bubbles
                .filter { $0.captureSourceLabel != nil }
                .sorted { $0.lastEditedAt > $1.lastEditedAt }
                .prefix(limit)
        )
    }

    func typeSummaries() -> [(type: BubbleType, count: Int, query: String)] {
        BubbleType.allCases
            .compactMap { type in
                let count = bubbles.filter { $0.type == type }.count
                guard count > 0 else { return nil }
                return (type: type, count: count, query: type.rawValue)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.type.label < rhs.type.label
                }
                return lhs.count > rhs.count
            }
    }

    func captureSourceSummaries() -> [(label: String, count: Int, query: String)] {
        let grouped = Dictionary(grouping: bubbles.compactMap { bubble -> (String, String)? in
            guard let label = bubble.captureSourceLabel else { return nil }
            return (label, captureSearchTerm(for: label))
        }) { $0.0 }

        return grouped
            .map { label, values in
                (label: label, count: values.count, query: values.first?.1 ?? label.lowercased())
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.label < rhs.label
                }
                return lhs.count > rhs.count
            }
    }

    func captureHostSummaries(limit: Int = 6) -> [(host: String, count: Int)] {
        let grouped = Dictionary(grouping: bubbles.compactMap(\.sourceHostLabel)) { $0 }

        return grouped
            .map { host, values in
                (host: host, count: values.count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.host < rhs.host
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func captureAppSummaries(limit: Int = 6) -> [(app: String, count: Int)] {
        let grouped = Dictionary(grouping: bubbles.compactMap(\.sourceAppLabel)) { $0 }

        return grouped
            .map { app, values in
                (app: app, count: values.count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.app < rhs.app
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func sourceConversationSummaries(limit: Int = 6) -> [(conversation: String, count: Int)] {
        let grouped = Dictionary(grouping: bubbles.compactMap(\.sourceConversationSearchLabel)) { $0 }

        return grouped
            .map { conversation, values in
                (conversation: conversation, count: values.count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.conversation < rhs.conversation
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func captureFileSummaries(limit: Int = 6) -> [(file: String, count: Int)] {
        let grouped = Dictionary(grouping: bubbles.flatMap(\.sourceFileLabels)) { $0 }

        return grouped
            .map { file, values in
                (file: file, count: values.count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.file < rhs.file
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func captureFolderSummaries(limit: Int = 6) -> [(folder: String, count: Int)] {
        let grouped = Dictionary(grouping: bubbles.compactMap(\.sourceFileLocationLabel)) { $0 }

        return grouped
            .map { folder, values in
                (folder: folder, count: values.count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.folder < rhs.folder
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    func searchMatches() -> [Bubble] {
        let snapshot = searchSnapshot(limit: max(bubbles.count, 12))
        return snapshot.isActive ? snapshot.visibleBubbles : bubbles
    }

    func searchSnapshot(limit: Int = 12) -> BubbleSearchSnapshot {
        let queryDescriptor = normalizedSearchDescriptor()
        let query = queryDescriptor.normalized
        guard !query.isEmpty else {
            return BubbleSearchSnapshot(query: "", displayQuery: "", direct: [], related: [], relatedTerms: [], isExactPhrase: false)
        }

        let expandedTerms = expandedSearchTerms(for: query)
        let queryTerms = tokenSet(for: query)
        let relatedTerms = queryDescriptor.isExactPhrase ? [] : Array(expandedTerms.subtracting(queryTerms)).sorted()

        let direct: [BubbleSearchMatch] = bubbles
            .compactMap { bubble in
                guard directMatchExists(in: bubble, descriptor: queryDescriptor) else { return nil }
                return BubbleSearchMatch(
                    bubble: bubble,
                    kind: .direct,
                    reason: directReason(for: bubble, descriptor: queryDescriptor),
                    snippet: searchSnippet(for: bubble, query: query)
                )
            }
            .sorted { $0.bubble.lastEditedAt > $1.bubble.lastEditedAt }

        let directIds = Set(direct.map(\.bubble.id))
        let related: [BubbleSearchMatch] = bubbles
            .compactMap { bubble in
                guard !directIds.contains(bubble.id) else { return nil }
                guard !queryDescriptor.isExactPhrase else { return nil }
                let bubbleTerms = tokenSet(for: bubble.searchableText)
                let semanticOverlap = bubbleTerms.intersection(expandedTerms)
                let linksToDirect = bubble.links.contains { directIds.contains($0) }
                guard !semanticOverlap.isEmpty || linksToDirect else { return nil }
                return BubbleSearchMatch(
                    bubble: bubble,
                    kind: .related,
                    reason: relatedReason(overlap: semanticOverlap, linksToDirect: linksToDirect),
                    snippet: relatedSnippet(for: bubble, overlap: semanticOverlap)
                )
            }
            .sorted { $0.bubble.lastEditedAt > $1.bubble.lastEditedAt }
            .prefix(limit)
            .map { $0 }

        return BubbleSearchSnapshot(
            query: query,
            displayQuery: queryDescriptor.display,
            direct: Array(direct.prefix(limit)),
            related: related,
            relatedTerms: relatedTerms,
            isExactPhrase: queryDescriptor.isExactPhrase
        )
    }

    func searchMatchKind(for bubble: Bubble) -> SearchMatchKind? {
        let snapshot = searchSnapshot(limit: max(bubbles.count, 12))
        guard snapshot.isActive else { return nil }
        if snapshot.direct.contains(where: { $0.bubble.id == bubble.id }) {
            return .direct
        }
        if snapshot.related.contains(where: { $0.bubble.id == bubble.id }) {
            return .related
        }
        return nil
    }

    func relatedBubbles(for bubble: Bubble, limit: Int = 6) -> [Bubble] {
        guard bubble.memoryScope == .shared else { return [] }

        let titleWords = Set(
            bubble.displayTitle
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 3 }
        )

        return bubbles
            .filter { candidate in
                candidate.id != bubble.id &&
                candidate.memoryScope == .shared &&
                (!Set(candidate.searchableText.split(separator: " ").map(String.init)).isDisjoint(with: titleWords) ||
                 bubble.links.contains(candidate.id))
            }
            .sorted { $0.lastEditedAt > $1.lastEditedAt }
            .prefix(limit)
            .map { $0 }
    }

    func linkedBubbles(for bubble: Bubble, limit: Int = 4) -> [Bubble] {
        bubble.links
            .compactMap { linkedID in
                bubbles.first(where: { $0.id == linkedID })
            }
            .sorted { $0.lastEditedAt > $1.lastEditedAt }
            .prefix(limit)
            .map { $0 }
    }

    func suggestedTags(for bubble: Bubble, limit: Int = 6) -> [String] {
        let existing = Set(bubble.tags)
        let bubbleTerms = tokenSet(for: bubble.displayTitle + " " + bubble.displayBody + " " + bubble.messages.map(\.text).joined(separator: " "))
        var suggestions: [String] = []

        for group in Self.semanticGroups {
            let overlap = group.intersection(bubbleTerms).sorted()
            for tag in overlap where !existing.contains(tag) && !suggestions.contains(tag) {
                suggestions.append(tag)
            }
        }

        return Array(suggestions.prefix(limit))
    }

    private func createBubble(
        title: String,
        bodyText: String,
        type: BubbleType,
        x: Double,
        y: Double,
        linkToSelection: Bool
    ) {
        var links: [UUID] = []
        if linkToSelection, let selectedId {
            links.append(selectedId)
        }

        let bubble = Bubble(
            type: type,
            title: resolvedTitle(from: title),
            bodyText: bodyText,
            x: x,
            y: y,
            links: links,
            messages: []
        )

        bubbles.insert(bubble, at: 0)
        selectedId = bubble.id
        statusText = "Created a new bubble."
        scheduleAutosave()
    }

    private func resolvedTitle(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled bubble" : trimmed
    }

    private func selectedIndex() -> Int? {
        guard let selectedId else { return bubbles.indices.first }
        return bubbles.firstIndex { $0.id == selectedId }
    }

    private func normalizedSearchDescriptor() -> (normalized: String, display: String, isExactPhrase: Bool) {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("", "", false)
        }

        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            let phrase = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return (phrase.lowercased(), phrase, true)
        }

        return (trimmed.lowercased(), trimmed, false)
    }

    private func rememberSearchQueryIfNeeded() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(8))
        UserDefaults.standard.set(recentSearches, forKey: searchHistoryKey)
    }

    private func expandedSearchTerms(for query: String) -> Set<String> {
        let baseTerms = tokenSet(for: query)
        guard !baseTerms.isEmpty else { return [] }

        var expanded = baseTerms
        for group in Self.semanticGroups {
            if !group.isDisjoint(with: baseTerms) {
                expanded.formUnion(group)
            }
        }
        return expanded
    }

    private func tokenSet(for text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 2 }
        )
    }

    private func parseTags(from rawTags: String) -> [String] {
        Array(
            Set(
                rawTags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private func captureSearchTerm(for label: String) -> String {
        switch label.lowercased() {
        case "webpage":
            return "webpage"
        case "selection":
            return "textselection"
        case "chat":
            return "chatexport"
        case "captured note":
            return "note"
        case "image":
            return "imagefile"
        case "audio":
            return "audiofile"
        case "video":
            return "videofile"
        default:
            return label.lowercased()
        }
    }

    private func searchSnippet(for bubble: Bubble, query: String) -> String? {
        let queryTerms = tokenSet(for: query)
        if let titleSnippet = matchedSnippet(in: bubble.displayTitle, terms: queryTerms) {
            return titleSnippet
        }
        if let bodySnippet = matchedSnippet(in: bubble.displayBody, terms: queryTerms) {
            return bodySnippet
        }
        if let messageSnippet = bubble.messages.compactMap({ matchedSnippet(in: $0.text, terms: queryTerms) }).first {
            return messageSnippet
        }
        if !bubble.tags.isEmpty {
            let joinedTags = bubble.tags.joined(separator: ", ")
            if let tagSnippet = matchedSnippet(in: joinedTags, terms: queryTerms) {
                return tagSnippet
            }
        }
        return nil
    }

    private func relatedSnippet(for bubble: Bubble, overlap: Set<String>) -> String? {
        let terms = Array(overlap.prefix(3))
        guard !terms.isEmpty else { return nil }

        if let bodySnippet = matchedSnippet(in: bubble.displayBody, terms: Set(terms)) {
            return bodySnippet
        }
        if let messageSnippet = bubble.messages.compactMap({ matchedSnippet(in: $0.text, terms: Set(terms)) }).first {
            return messageSnippet
        }
        if !bubble.tags.isEmpty {
            let joinedTags = bubble.tags.joined(separator: ", ")
            if let tagSnippet = matchedSnippet(in: joinedTags, terms: Set(terms)) {
                return tagSnippet
            }
        }
        return nil
    }

    private func matchedSnippet(in text: String, terms: Set<String>) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let compact = trimmed.replacingOccurrences(of: "\n", with: " ")
        let lowercase = compact.lowercased()

        if let term = terms.first(where: { lowercase.contains($0.lowercased()) }),
           let range = lowercase.range(of: term.lowercased()) {
            let distanceToStart = lowercase.distance(from: lowercase.startIndex, to: range.lowerBound)
            let startOffset = max(0, distanceToStart - 36)
            let endOffset = min(compact.count, distanceToStart + term.count + 56)
            let startIndex = compact.index(compact.startIndex, offsetBy: startOffset)
            let endIndex = compact.index(compact.startIndex, offsetBy: endOffset)
            let prefix = startOffset > 0 ? "..." : ""
            let suffix = endOffset < compact.count ? "..." : ""
            return prefix + compact[startIndex..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines) + suffix
        }

        return String(compact.prefix(92))
    }

    private func directMatchExists(in bubble: Bubble, descriptor: (normalized: String, display: String, isExactPhrase: Bool)) -> Bool {
        if descriptor.isExactPhrase {
            return bubble.searchableText.contains(descriptor.normalized)
        }
        return bubble.searchableText.contains(descriptor.normalized)
    }

    private func suggestedTags(for payload: BubbleCapturePayload) -> [String] {
        var tags = parseTags(from: [payload.sourceType.rawValue, payload.sourceApp ?? ""].joined(separator: ","))
        if payload.sourceType == .imageFile {
            tags.append(contentsOf: ["image", "photo", "visual", "media"])
        }
        if payload.sourceType == .audioFile {
            tags.append(contentsOf: ["audio", "sound", "voice", "recording", "media"])
        }
        if payload.sourceType == .videoFile {
            tags.append(contentsOf: ["video", "movie", "clip", "visual", "media"])
        }
        if let suggestedTags = payload.suggestedTags {
            tags.append(contentsOf: suggestedTags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
        }

        let bodyTerms = tokenSet(for: payload.capturedText + " " + payload.sourceTitle + " " + payload.suggestedBubbleTitle)
        for group in Self.semanticGroups {
            let overlap = group.intersection(bodyTerms)
            if !overlap.isEmpty, let chosen = overlap.sorted().first {
                tags.append(chosen)
            }
        }

        return Array(Set(tags)).sorted()
    }

    private func sharedSourceApp(for payloads: [BubbleCapturePayload]) -> String? {
        let sourceApps = Set(
            payloads.compactMap { payload in
                let trimmed = (payload.sourceApp ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )

        guard sourceApps.count == 1 else { return nil }
        return sourceApps.first
    }

    private func chatConversationImportSuffix(for payloads: [BubbleCapturePayload]) -> String {
        guard payloads.contains(where: { $0.sourceType == .chatExport }) else { return "" }

        let conversationLabels = Array(
            Set(
                payloads.compactMap { payload in
                    payload.sourceConversationLabel ?? payload.sourceConversationIDLabel
                }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()

        guard !conversationLabels.isEmpty else { return "" }

        if conversationLabels.count == 1 {
            return " from \(conversationLabels[0])"
        }

        return " across \(conversationLabels.count) conversations"
    }

    private func sharedTargetBubble(for targetIDs: [UUID]) -> Bubble? {
        let targetIDs = Set(targetIDs)
        guard targetIDs.count == 1, let targetID = targetIDs.first else { return nil }
        return bubbles.first { $0.id == targetID }
    }

    private func directReason(for bubble: Bubble, descriptor: (normalized: String, display: String, isExactPhrase: Bool)) -> String {
        let query = descriptor.normalized
        if bubble.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
            return descriptor.isExactPhrase ? "matched exact phrase in tags" : "matched tag"
        }
        if bubble.displayTitle.lowercased().contains(query) {
            return descriptor.isExactPhrase ? "matched exact phrase in title" : "matched title"
        }
        if bubble.displayBody.lowercased().contains(query) {
            return descriptor.isExactPhrase ? "matched exact phrase in writing" : "matched writing"
        }
        return descriptor.isExactPhrase ? "matched exact phrase in conversation" : "matched conversation"
    }

    private func relatedReason(overlap: Set<String>, linksToDirect: Bool) -> String {
        if linksToDirect {
            return "linked to a direct match"
        }

        if let first = overlap.sorted().first {
            return "related through \(first)"
        }

        return "semantic overlap"
    }

    static func defaultVaultURL() -> URL {
        let projectVault = URL(fileURLWithPath: "/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any/bubblepath-vault/bubblepath-data.json")
        if FileManager.default.fileExists(atPath: projectVault.deletingLastPathComponent().path) {
            return projectVault
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents
            .appendingPathComponent("BubblePath", isDirectory: true)
            .appendingPathComponent("bubblepath-data.json")
    }

    static func backupsDirectoryURL() -> URL {
        let projectVault = defaultVaultURL()
        if FileManager.default.fileExists(atPath: projectVault.deletingLastPathComponent().path) {
            return projectVault
                .deletingLastPathComponent()
                .appendingPathComponent("backups", isDirectory: true)
        }

        return projectVault
            .deletingLastPathComponent()
            .appendingPathComponent("backups", isDirectory: true)
    }

    private static let semanticGroups: [Set<String>] = [
        ["bible", "scripture", "scriptures", "gospel", "sermon", "sermons", "theology", "christian", "christ", "jesus", "verse", "verses", "old", "new", "testament", "genesis", "psalm", "psalms", "proverb", "proverbs", "romans"],
        ["philosophy", "philosophical", "ethics", "metaphysics", "meaning", "truth", "reason", "existential", "ontology"],
        ["writing", "writer", "draft", "essay", "substack", "post", "article", "publish", "published", "revision"],
        ["memory", "journal", "second", "brain", "notes", "recall", "remember", "retrieval", "archive"],
        ["prayer", "church", "devotional", "faith", "discipleship", "apologetics", "counsel", "counselling", "pastoral"],
        ["media", "image", "photo", "picture", "visual", "audio", "sound", "voice", "recording", "video", "movie", "clip"]
    ]

}

enum BubbleDateCoding {
    static func encode(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func decode(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
