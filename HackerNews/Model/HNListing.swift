import Foundation
import Fuzi

enum ListingType: String, CaseIterable {
    case news
    case ask
    case show
    case newest
    case jobs

    var displayName: String {
        switch self {
        case .news: return "Front Page"
        case .ask: return "Ask HN"
        case .show: return "Show HN"
        case .newest: return "New Stories"
        case .jobs: return "Jobs"
        }
    }

    var iconName: String {
        switch self {
        case .news: return "arrow.up.circle"
        case .ask: return "questionmark.bubble"
        case .show: return "eye"
        case .newest: return "clock"
        case .jobs: return "briefcase"
        }
    }
}

@MainActor class HNListing: ObservableObject {
    let listingType: ListingType

    @Published var items: [HNItem] = []
    @Published var isLoading = false
    @Published var hasMoreContent = false
    @Published var loadError: String?
    @Published private(set) var lastUpdated: Date?

    private var nextPageUrl: String?
    weak var cache: AppCache?

    init(_ listingType: ListingType, cache: AppCache? = nil) {
        self.listingType = listingType
        self.cache = cache
    }

    func loadInitialContent() {
        if items.isEmpty {
            loadMoreContent()
        }
    }

    func staleRefresh() {
        guard !isLoading else { return }
        items = []
        nextPageUrl = nil
        hasMoreContent = false
        loadMoreContent(reload: true)
    }

    func refreshIfStale() {
        if case .stale = Freshness(for: lastUpdated) {
            debugLog("listing/\(listingType)", "stale -> refresh")
            staleRefresh()
        }
    }

    func loadMoreContent(reload: Bool = false) async {
        await withCheckedContinuation { continuation in
            loadMoreContent(reload: reload) { continuation.resume() }
        }
    }

    func loadMoreContent(reload: Bool = false, completion: (() -> Void)? = nil) {
        guard !isLoading else { return }

        let isFirstPageFetch = reload || items.isEmpty
        isLoading = true
        loadError = nil
        if reload {
            self.nextPageUrl = nil
        }

        Task {
            do {
                let url = self.nextPageUrl ?? "https://news.ycombinator.com/\(self.listingType)"
                let doc = try await RequestController.shared.makeRequest(endpoint: url)
                let newItems = self.parseItems(doc: doc)
                self.nextPageUrl = self.parseMoreLink(doc: doc)

                self.hasMoreContent = self.nextPageUrl != nil
                if reload {
                    self.items = newItems
                } else {
                    self.items.append(contentsOf: newItems)
                }
                if isFirstPageFetch {
                    self.lastUpdated = .now
                    debugLog("listing/\(self.listingType)", "loaded \(self.items.count) items\(reload ? " (reload)" : "")")
                }
                self.isLoading = false
                completion?()
            } catch {
                self.isLoading = false
                self.loadError = error.localizedDescription
                debugLog("listing/\(self.listingType)", "load error: \(error.localizedDescription)")
                completion?()
            }
        }
    }

    func parseItems(doc: HTMLDocument) -> [HNItem] {
        let itemList = doc.css("tr.athing")
        var newItems: [HNItem] = []

        for node in itemList {
            if let parsed = HNItem(withXmlNode: node) {
                let canonical = cache?.canonicalize(parsed) ?? parsed
                newItems.append(canonical)
            }
        }

        return newItems
    }

    func parseMoreLink(doc: HTMLDocument) -> String? {
        guard let moreLink = doc.css("a.morelink").first, let href = moreLink["href"] else {
            return nil
        }
        let baseURL = URL(string: "https://news.ycombinator.com/\(self.listingType)")!
        return URL(string: href, relativeTo: baseURL)?.absoluteString
    }
}
