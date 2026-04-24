import Foundation

@MainActor
final class CloudSyncStatusStore: ObservableObject {
    enum Phase: String {
        case localOnly = "Local only"
        case iCloudPlanned = "iCloud planned"
    }

    @Published var phase: Phase = .iCloudPlanned

    var title: String { phase.rawValue }

    var detail: String {
        switch phase {
        case .localOnly:
            return "BubblePath is saving locally on this Mac."
        case .iCloudPlanned:
            return "This Mac scaffold is local-first now and designed to grow into CloudKit sync next."
        }
    }

    var nextStep: String {
        "Next sync milestone: add CloudKit-backed storage after local native save/load stays stable."
    }
}
