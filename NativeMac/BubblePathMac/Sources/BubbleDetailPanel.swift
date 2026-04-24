import AppKit
import SwiftUI

struct BubbleDetailPanel: View {
    @EnvironmentObject private var store: BubbleStore
    @EnvironmentObject private var aiSettings: AISettingsStore

    let bubble: Bubble

    @State private var messageDraft = ""
    @State private var askingGPT = false

    private var style: BubbleStyle {
        bubble.type.bubbleStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(bubble.type.label, systemImage: style.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.accentColor)
                    Text("Created \(timestamp(bubble.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Edited \(timestamp(bubble.lastEditedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    HapticsService.shared.perform(.create)
                    store.duplicateSelectedBubble()
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.46), in: Circle())
                .help("Duplicate this bubble")

                Button(role: .destructive) {
                    HapticsService.shared.perform(.select)
                    store.deleteSelectedBubble()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.46), in: Circle())
                .help("Delete this bubble")

                Button {
                    HapticsService.shared.perform(.select)
                    store.clearSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.46), in: Circle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Untitled bubble", text: Binding(
                    get: { bubble.displayTitle },
                    set: { store.updateSelected(title: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(style.backgroundTint.opacity(0.20), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Type", selection: Binding(
                    get: { bubble.type },
                    set: { store.updateSelectedType($0) }
                )) {
                    ForEach(BubbleType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)

                Text("Writing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { bubble.displayBody },
                    set: { store.updateSelectedBody($0) }
                ))
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 220)
                .background(style.backgroundTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Memory")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Memory", selection: Binding(
                    get: { bubble.memoryScope },
                    set: { store.updateSelectedMemoryScope($0) }
                )) {
                    ForEach(BubbleMemoryScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                Text(bubble.memoryScope.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if bubble.captureSourceLabel != nil || bubble.sourceHostLabel != nil || bubble.sourceFileURL != nil || bubble.sourceAppLabel != nil || bubble.sourceConversationLabel != nil || bubble.sourceConversationIDLabel != nil || !bubble.sourceFileLabels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        if let captureSourceLabel = bubble.captureSourceLabel,
                           let captureSourceQuery = bubble.captureSourceQuery {
                            let isActiveSourceType = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(captureSourceQuery) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = captureSourceQuery
                            } label: {
                                Text(captureSourceLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(isActiveSourceType ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceHostLabel = bubble.sourceHostLabel {
                            let isActiveHost = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceHostLabel) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceHostLabel
                            } label: {
                                Text(sourceHostLabel)
                                    .font(.caption2)
                                    .foregroundStyle(isActiveHost ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceFileURL = bubble.sourceFileURL {
                            let sourceFileQuery = bubble.sourceFileLocationLabel ?? sourceFileURL.lastPathComponent
                            let isActiveFileURL = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceFileQuery) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceFileQuery
                            } label: {
                                Text("Local file")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(isActiveFileURL ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceAppLabel = bubble.sourceAppLabel {
                            let isActiveApp = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceAppLabel) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceAppLabel
                            } label: {
                                Text(sourceAppLabel)
                                    .font(.caption2)
                                    .foregroundStyle(isActiveApp ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceConversationLabel = bubble.sourceConversationLabel {
                            let isActiveConversation = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceConversationLabel) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceConversationLabel
                            } label: {
                                Text(sourceConversationLabel)
                                    .font(.caption2)
                                    .foregroundStyle(isActiveConversation ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceConversationIDLabel = bubble.sourceConversationIDLabel {
                            let isActiveConversationID = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceConversationIDLabel) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceConversationIDLabel
                            } label: {
                                Text(sourceConversationIDLabel)
                                    .font(.caption2)
                                    .foregroundStyle(isActiveConversationID ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(bubble.sourceFileLabels.prefix(3), id: \.self) { sourceFileLabel in
                            let isActiveFile = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sourceFileLabel) == .orderedSame
                            Button {
                                HapticsService.shared.perform(.select)
                                store.searchQuery = sourceFileLabel
                            } label: {
                                Text(sourceFileLabel)
                                    .font(.caption2)
                                    .foregroundStyle(isActiveFile ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                        if let sourceURL = bubble.sourceURL {
                            Text(sourceURL.absoluteString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                            if !sourceURL.isFileURL {
                                Button {
                                    openSourceURL(sourceURL)
                                } label: {
                                    Text("Open Source Link")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Open this source link")
                            }
                            Button {
                                copySourceURL(sourceURL)
                            } label: {
                                Text("Copy Source URL")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Copy this source URL")
                        }
                        if let sourceFileURL = bubble.sourceFileURL {
                            Button {
                                revealSourceFile(sourceFileURL)
                            } label: {
                                Text("Reveal in Finder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Show this captured file in Finder")
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(
                    "Separate tags with commas",
                    text: Binding(
                        get: { bubble.tags.joined(separator: ", ") },
                        set: { store.updateSelectedTags(from: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                if !bubble.tags.isEmpty {
                    FlowLayout(alignment: .leading, spacing: 6) {
                        ForEach(bubble.tags, id: \.self) { tag in
                            Button {
                                store.searchQuery = tag
                            } label: {
                                Text(tag)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                let suggestions = store.suggestedTags(for: bubble)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Suggested")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        FlowLayout(alignment: .leading, spacing: 6) {
                            ForEach(suggestions, id: \.self) { tag in
                                Button {
                                    store.addSelectedTag(tag)
                                } label: {
                                    Text("+ \(tag)")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            if !bubble.links.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(bubble.links, id: \.self) { id in
                            if let linked = store.bubbles.first(where: { $0.id == id }) {
                                Button {
                                    HapticsService.shared.perform(.open)
                                    store.select(linked.id)
                                } label: {
                                    Text(linked.shortLabel)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            let related = store.relatedBubbles(for: bubble)
            if !related.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared Memory Nearby")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(related, id: \.id) { candidate in
                            Button {
                                HapticsService.shared.perform(.select)
                                store.select(candidate.id)
                            } label: {
                                Text(candidate.shortLabel)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Companion")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let latest = bubble.messages.last {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latest.role == .assistant ? "Latest GPT reply" : "Latest note")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(latest.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(5)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: 10) {
                    TextField("Ask BubblePath to expand this thought...", text: $messageDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(askingGPT ? "Thinking..." : "Ask GPT") {
                        askGPT()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(askingGPT || messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("Model: \(aiSettings.model)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.borderColor.opacity(0.52), lineWidth: 1.2)
        )
        .shadow(color: style.glowColor.opacity(0.18), radius: 24, y: 12)
    }

    private func askGPT() {
        let prompt = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        store.addMessage(text: prompt, role: .user)
        messageDraft = ""
        askingGPT = true
        let pendingId = store.addPendingAssistantMessage()

        let client = OpenAIClient(
            apiKeyProvider: { aiSettings.apiKey },
            model: aiSettings.model,
            guidePrompt: aiSettings.guidePrompt
        )

        Task {
            do {
                let activeBubble = store.selectedBubble ?? bubble
                let sharedContext = deduplicatedBubbles(
                    store.bubbles.filter { activeBubble.links.contains($0.id) } +
                    store.relatedBubbles(for: activeBubble)
                )
                let reply = try await client.respond(
                    to: activeBubble,
                    userPrompt: prompt,
                    linkedBubbles: sharedContext,
                    recentMessages: Array(activeBubble.messages.suffix(10))
                )
                await MainActor.run {
                    if let pendingId {
                        store.resolvePendingAssistantMessage(id: pendingId, text: reply, model: aiSettings.model)
                    } else {
                        store.addMessage(text: reply, role: .assistant, model: aiSettings.model)
                    }
                    store.statusText = "GPT replied from \(aiSettings.model)."
                    askingGPT = false
                }
            } catch {
                await MainActor.run {
                    let failure = "OpenAI request failed: \(error.localizedDescription)"
                    if let pendingId {
                        store.resolvePendingAssistantMessage(id: pendingId, text: failure)
                    } else {
                        store.addMessage(text: failure, role: .note)
                    }
                    store.statusText = failure
                    askingGPT = false
                }
            }
        }
    }

    private func revealSourceFile(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            store.statusText = "That local source file is no longer at \(url.lastPathComponent)."
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        store.statusText = "Asked Finder to reveal \(url.lastPathComponent)."
    }

    private func openSourceURL(_ url: URL) {
        guard NSWorkspace.shared.open(url) else {
            store.statusText = "Could not open source link."
            return
        }

        store.statusText = "Opened source link."
    }

    private func copySourceURL(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        store.statusText = "Copied source URL."
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deduplicatedBubbles(_ bubbles: [Bubble]) -> [Bubble] {
        var seen = Set<UUID>()
        return bubbles.filter { bubble in
            seen.insert(bubble.id).inserted
        }
    }
}

private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .center
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? 320, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            if alignment == .center {
                x += max(0, (bounds.width - row.width) / 2)
            } else if alignment == .trailing {
                x += max(0, bounds.width - row.width)
            }

            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if nextWidth > width, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.append(subview: subview, size: size, spacing: spacing)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(subview: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !items.isEmpty {
                width += spacing
            }
            items.append(Item(subview: subview, size: size))
            width += size.width
            height = max(height, size.height)
        }
    }

    private struct Item {
        var subview: LayoutSubview
        var size: CGSize
    }
}
