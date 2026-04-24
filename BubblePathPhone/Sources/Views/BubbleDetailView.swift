import SwiftUI

struct BubbleDetailView: View {
    @EnvironmentObject private var store: BubbleStore
    @Environment(\.dismiss) private var dismiss

    let bubble: Bubble

    @State private var title: String
    @State private var bodyText: String

    init(bubble: Bubble) {
        self.bubble = bubble
        _title = State(initialValue: bubble.title)
        _bodyText = State(initialValue: bubble.body)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BubbleCanvasBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Title", text: $title)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .textFieldStyle(.plain)

                            Text(metadataText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        TextEditor(text: $bodyText)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .frame(minHeight: 320)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)

                        Text("Everything in this bubble is stored locally on this iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .padding(18)
                }
            }
            .navigationTitle("Bubble")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
            .onDisappear {
                saveChanges()
            }
        }
    }

    private var metadataText: String {
        "Created \(format(date: bubble.createdAt))  •  Edited \(format(date: bubble.updatedAt))"
    }

    private func saveAndDismiss() {
        saveChanges()
        dismiss()
    }

    private func saveChanges() {
        store.updateBubble(id: bubble.id, title: title, body: bodyText)
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
