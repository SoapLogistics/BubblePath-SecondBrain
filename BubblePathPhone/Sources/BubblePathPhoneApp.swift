import SwiftUI

@main
struct BubblePathPhoneApp: App {
    @StateObject private var store = BubbleStore()

    var body: some Scene {
        WindowGroup {
            BubbleCanvasScreen()
                .environmentObject(store)
                .task {
                    await store.load()
                }
        }
    }
}
