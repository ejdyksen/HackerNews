// Lightweight in-memory cache for canonical story objects and listing models so
// navigation can reuse state instead of recreating the same observable objects.
import Foundation
import SwiftUI

@MainActor final class AppCache: ObservableObject {
    private var listings: [HNListingDestination: HNListing] = [:]
    private var items: [Int: HNItem] = [:]
    private var users: [String: HNUser] = [:]
    private var linkPreviews: [URL: LinkPreview] = [:]
    private var accessOrder: [Int] = []
    private let maxItems = 20

    func listing(for destination: HNListingDestination) -> HNListing {
        if let existing = listings[destination] { return existing }
        let created = HNListing(destination, cache: self)
        listings[destination] = created
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

    func canonicalize(_ parsed: ParsedHNItem) -> HNItem {
        if let existing = items[parsed.id] {
            existing.updateMetadata(from: parsed)
            touch(parsed.id)
            return existing
        }
        let item = HNItem(parsed: parsed)
        items[parsed.id] = item
        touch(parsed.id)
        evictIfNeeded()
        return item
    }

    func user(for username: String) -> HNUser {
        if let existing = users[username] { return existing }
        let created = HNUser(username: username)
        users[username] = created
        return created
    }

    func linkPreview(for url: URL) -> LinkPreview {
        let cacheKey = url.absoluteURL
        if let existing = linkPreviews[cacheKey] { return existing }
        let created = LinkPreview(url: cacheKey)
        linkPreviews[cacheKey] = created
        return created
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
