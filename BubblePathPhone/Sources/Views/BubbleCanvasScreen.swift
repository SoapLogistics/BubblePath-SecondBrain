import SwiftUI

struct BubbleCanvasScreen: View {
    @EnvironmentObject private var store: BubbleStore
    @State private var showingCaptureSheet = false

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                ZStack {
                    BubbleCanvasBackground()

                    ForEach(store.bubbles) { bubble in
                        BubbleNodeView(
                            bubble: bubble,
                            title: store.title(for: bubble),
                            subtitle: store.subtitle(for: bubble),
                            timestamp: timeline.date
                        )
                        .position(position(for: bubble, in: proxy.size, time: timeline.date))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let point = CGPoint(
                                        x: value.location.x / max(proxy.size.width, 1),
                                        y: value.location.y / max(proxy.size.height, 1)
                                    )
                                    let distance = hypot(value.translation.width, value.translation.height)
                                    if distance < 8 {
                                        store.openBubble(bubble)
                                    } else {
                                        store.repositionBubble(id: bubble.id, normalizedPoint: point)
                                    }
                                }
                        )
                    }

                    if store.bubbles.isEmpty {
                        BubbleEmptyState()
                    }

                    VStack {
                        header
                        Spacer()
                    }
                    .padding(18)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let point = CGPoint(
                                x: value.location.x / max(proxy.size.width, 1),
                                y: value.location.y / max(proxy.size.height, 1)
                            )
                            store.createBubble(at: point)
                        }
                )
            }
        }
        .sheet(item: selectedBubbleBinding) { bubble in
            BubbleDetailView(bubble: bubble)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingCaptureSheet) {
            CaptureSheet()
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BubblePath")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("A living space for thoughts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let lastSavedAt = store.lastSavedAt {
                    Text("Saved \(lastSavedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                showingCaptureSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            CanvasStatusBadge(text: store.statusText)
        }
    }

    private var selectedBubbleBinding: Binding<Bubble?> {
        Binding(
            get: { store.selectedBubble },
            set: { bubble in
                if let bubble {
                    store.selectedBubbleID = bubble.id
                } else {
                    store.closeBubble()
                }
            }
        )
    }

    private func position(for bubble: Bubble, in size: CGSize, time: Date) -> CGPoint {
        let t = time.timeIntervalSinceReferenceDate
        let driftX = sin(t * 0.38 + bubble.floatSeed) * 5.0
        let driftY = cos(t * 0.33 + bubble.floatSeed * 0.8) * 7.0
        return CGPoint(
            x: min(max(bubble.x * size.width + driftX, 72), size.width - 72),
            y: min(max(bubble.y * size.height + driftY, 108), size.height - 72)
        )
    }
}

private struct CaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BubbleStore

    @State private var sourceType: BubbleCaptureSourceType = .webpage
    @State private var sourceTitle = ""
    @State private var sourceURLString = ""
    @State private var suggestedTitle = ""
    @State private var capturedText = ""
    @State private var appendToSelected = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Source", selection: $sourceType) {
                        ForEach(BubbleCaptureSourceType.allCases) { type in
                            Text(label(for: type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(sourceDescription(for: sourceType))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Source title", text: $sourceTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Source URL", text: $sourceURLString)
                        .textFieldStyle(.roundedBorder)
                        .modifier(URLInputStyle())

                    TextField("Bubble title", text: $suggestedTitle)
                        .textFieldStyle(.roundedBorder)

                    if suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Suggested title: \(suggestedTitlePreview)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $capturedText)
                        .frame(minHeight: 220)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Toggle(isOn: $appendToSelected) {
                        Text("Append to the selected bubble")
                    }
                    .disabled(store.selectedBubble == nil)

                    if let selected = store.selectedBubble {
                        if appendToSelected {
                            Text("Appending into “\(store.title(for: selected))”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("BubblePath can also tuck this into “\(store.title(for: selected))” if it belongs with the thought you already have open.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("This capture will become a new bubble.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(BubbleCanvasBackground())
            .navigationTitle("Capture")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCapture() }
                        .disabled(capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if store.selectedBubble != nil {
                appendToSelected = true
            }
            autofillSuggestedTitleIfNeeded()
        }
        .onChange(of: sourceTitle) { _, _ in
            autofillSuggestedTitleIfNeeded()
        }
        .onChange(of: capturedText) { _, _ in
            autofillSuggestedTitleIfNeeded()
        }
    }

    private func saveCapture() {
        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = BubbleCapturePayload(
            sourceType: sourceType,
            sourceTitle: sourceTitle,
            sourceURL: trimmedURL.isEmpty ? nil : URL(string: trimmedURL),
            capturedText: capturedText,
            capturedAt: Date(),
            suggestedBubbleTitle: suggestedTitle,
            targetBubbleID: appendToSelected ? store.selectedBubbleID : nil,
            sourceApp: "Manual Capture"
        )

        store.importCapture(payload)
        dismiss()
    }

    private var suggestedTitlePreview: String {
        let trimmedSuggested = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSuggested.isEmpty {
            return trimmedSuggested
        }

        let trimmedSource = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSource.isEmpty {
            return trimmedSource
        }

        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = URL(string: trimmedURL)?.host(percentEncoded: false), !host.isEmpty {
            return host.replacingOccurrences(of: "www.", with: "")
        }

        let trimmedText = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            return String(trimmedText.prefix(48))
        }

        return "Captured bubble"
    }

    private func autofillSuggestedTitleIfNeeded() {
        let trimmedSuggested = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSuggested.isEmpty else { return }
        suggestedTitle = suggestedTitlePreview
    }

    private func label(for type: BubbleCaptureSourceType) -> String {
        switch type {
        case .webpage:
            return "Webpage"
        case .textSelection:
            return "Selection"
        case .chatExport:
            return "Chat"
        case .note:
            return "Note"
        }
    }

    private func sourceDescription(for type: BubbleCaptureSourceType) -> String {
        switch type {
        case .webpage:
            return "Capture a page title, URL, and the part you want to remember."
        case .textSelection:
            return "Capture a quote, paragraph, or excerpt from something you were reading."
        case .chatExport:
            return "Capture a saved exchange from ChatGPT or another conversation."
        case .note:
            return "Drop in a loose thought or fragment that belongs in your memory web."
        }
    }
}

private struct URLInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
        #else
        content
        #endif
    }
}
