// Lightweight in-memory cache for canonical story objects and listing models so
// navigation can reuse state instead of recreating the same observable objects.
import Foundation
import SwiftUI

@MainActor final class AppCache: ObservableObject {
    private var listings: [HNListingDestination: HNListing] = [:]
    private var items: [Int: HNItem] = [:]
    private var users: [String: HNUser] = [:]
    private var linkPreviews: [URL: LinkPreview] = [:]

    // HNItem instances are intentionally retained for the full session. Listings
    // hold strong references to their items, so an LRU eviction here couldn't
    // actually free memory — it only allowed a second HNItem with the same id
    // to be created on the next parse, silently splitting vote and metadata
    // state between the two instances.
    func listing(for destination: HNListingDestination) -> HNListing {
        if let existing = listings[destination] { return existing }
        let created = HNListing(destination, cache: self)
        listings[destination] = created
        return created
    }

    func item(for id: Int) -> HNItem? {
        items[id]
    }

    func rememberItem(_ item: HNItem) {
        if items[item.id] == nil {
            items[item.id] = item
        }
    }

    func canonicalize(_ parsed: ParsedHNItem) -> HNItem {
        if let existing = items[parsed.id] {
            existing.updateMetadata(from: parsed)
            return existing
        }
        let item = HNItem(parsed: parsed)
        items[parsed.id] = item
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
}
