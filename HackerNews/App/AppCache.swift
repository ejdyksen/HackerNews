import Foundation
import SwiftUI

@MainActor final class AppCache: ObservableObject {
    private var listings: [ListingType: HNListing] = [:]
    private var items: [Int: HNItem] = [:]
    private var accessOrder: [Int] = []
    private let maxItems = 20

    func listing(for type: ListingType) -> HNListing {
        if let existing = listings[type] { return existing }
        let created = HNListing(type, cache: self)
        listings[type] = created
        return created
    }

    func item(for id: Int) -> HNItem? {
        guard let item = items[id] else { return nil }
        touch(id)
        return item
    }

    func rememberItem(_ item: HNItem) {
        if items[item.id] == nil {
            items[item.id] = item
        }
        touch(item.id)
        evictIfNeeded()
    }

    func canonicalize(_ parsed: HNItem) -> HNItem {
        if let existing = items[parsed.id] {
            existing.updateMetadata(from: parsed)
            touch(parsed.id)
            return existing
        }
        items[parsed.id] = parsed
        touch(parsed.id)
        evictIfNeeded()
        return parsed
    }

    private func touch(_ id: Int) {
        accessOrder.removeAll { $0 == id }
        accessOrder.append(id)
    }

    private func evictIfNeeded() {
        while accessOrder.count > maxItems {
            let oldest = accessOrder.removeFirst()
            items.removeValue(forKey: oldest)
        }
    }
}
