// Minimal app-wide state shared through the environment for cross-screen events
// that do not belong to a single view hierarchy, such as deep-link routing.
import Foundation
import SwiftUI

@MainActor final class AppState: ObservableObject {
    @Published var deepLinkItemID: Int?
    @Published var deepLinkUsername: String?
}

@MainActor final class ReadStateStore: ObservableObject {
    private let defaults: UserDefaults
    private let storageKey = "readItemsByTimestamp"
    private let retention: TimeInterval = 7 * 24 * 60 * 60

    @Published private var readTimestamps: [Int: TimeInterval] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isRead(_ itemID: Int) -> Bool {
        readTimestamps[itemID] != nil
    }

    func markRead(_ itemID: Int, now: Date = .now) {
        pruneExpiredEntries(now: now)
        readTimestamps[itemID] = now.timeIntervalSince1970
        save()
    }

    private func load(now: Date = .now) {
        let raw = defaults.dictionary(forKey: storageKey) as? [String: TimeInterval] ?? [:]
        readTimestamps = raw.reduce(into: [:]) { result, entry in
            if let itemID = Int(entry.key) {
                result[itemID] = entry.value
            }
        }
        pruneExpiredEntries(now: now)
    }

    private func pruneExpiredEntries(now: Date = .now) {
        let cutoff = now.timeIntervalSince1970 - retention
        let originalCount = readTimestamps.count
        readTimestamps = readTimestamps.filter { $0.value >= cutoff }
        if readTimestamps.count != originalCount {
            save()
        }
    }

    private func save() {
        let raw = readTimestamps.reduce(into: [String: TimeInterval]()) { result, entry in
            result[String(entry.key)] = entry.value
        }
        defaults.set(raw, forKey: storageKey)
    }
}
