import SwiftUI

extension Notification.Name {
    static let bubblePathImportClipboardJSON = Notification.Name("BubblePathImportClipboardJSON")
}

@main
struct BubblePathApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = BubbleStore()
    @StateObject private var aiSettings = AISettingsStore()
    @StateObject private var cloudSync = CloudSyncStatusStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(aiSettings)
                .environmentObject(cloudSync)
                .task {
                    await store.load()
                }
        }
        .windowStyle(.titleBar)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.flushAutosave()
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Bubble") {
                    HapticsService.shared.perform(.create)
                    store.createBubbleAtCanvasCenter()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Duplicate Bubble") {
                    HapticsService.shared.perform(.create)
                    store.duplicateSelectedBubble()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store.selectedBubble == nil)
            }

            CommandGroup(after: .saveItem) {
                Button("Import Clipboard JSON") {
                    NotificationCenter.default.post(name: .bubblePathImportClipboardJSON, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Save BubblePath Vault") {
                    try? store.save()
                    store.refreshBackupInfo()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }

            CommandMenu("Navigate") {
                Button("Select Next Bubble") {
                    HapticsService.shared.perform(.select)
                    store.selectNextBubble()
                }
                .keyboardShortcut("]", modifiers: [.command])

                Button("Select Previous Bubble") {
                    HapticsService.shared.perform(.select)
                    store.selectPreviousBubble()
                }
                .keyboardShortcut("[", modifiers: [.command])
            }
        }
    }
}
