import Foundation

@MainActor
final class AISettingsStore: ObservableObject {
    @Published var apiKey = ""
    @Published var model = "gpt-5.2"
    @Published var guidePrompt = defaultGuidePrompt
    @Published var statusText = "GPT settings are local to this Mac."

    private let defaults = UserDefaults.standard
    private let modelKey = "BubblePath.defaultModel"
    private let promptKey = "BubblePath.guidePrompt"

    init() {
        load()
    }

    func load() {
        apiKey = KeychainStore.readAPIKey() ?? ""
        model = defaults.string(forKey: modelKey) ?? "gpt-5.2"
        guidePrompt = defaults.string(forKey: promptKey) ?? defaultGuidePrompt
    }

    func save() {
        defaults.set(model, forKey: modelKey)
        defaults.set(guidePrompt, forKey: promptKey)

        do {
            try KeychainStore.saveAPIKey(apiKey)
            statusText = "Saved GPT settings to this Mac."
        } catch {
            statusText = "Could not save API key: \(error.localizedDescription)"
        }
    }
}

private let defaultGuidePrompt = [
    "You are the user's BubblePath thinking companion.",
    "Be warm, clear, honest, and grounded.",
    "Help turn messy thoughts into connected meaning without forcing structure too early.",
    "Ask one good question when that is more useful than giving advice.",
    "When the user wants action, help shape the next small concrete step."
].joined(separator: " ")
