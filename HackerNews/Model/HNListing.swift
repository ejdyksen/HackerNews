// Observable listing state. This model manages pagination and freshness for one
// story feed, while HNRepository handles the actual page fetch and parsing.
import Foundation

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

@MainActor final class HNListing: ObservableObject {
    let listingType: ListingType

    @Published var items: [HNItem] = []
    @Published var isLoading = false
    @Published var hasMoreContent = false
    @Published var loadError: String?
    @Published private(set) var lastUpdated: Date?

    private var nextPageURL: String?
    private var loadTask: Task<Void, Never>?
    private var activeLoadID: UUID?
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
        nextPageURL = nil
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
        await startLoad(reload: reload).value
    }

    func loadMoreContent(reload: Bool = false) {
        _ = startLoad(reload: reload)
    }

    @discardableResult
    private func startLoad(reload: Bool) -> Task<Void, Never> {
        if reload {
            loadTask?.cancel()
            loadTask = nil
        } else if let loadTask {
            return loadTask
        }

        if !reload && !hasMoreContent && !items.isEmpty {
            return Task {}
        }

        let isFirstPageFetch = reload || items.isEmpty
        if reload {
            nextPageURL = nil
        }

        let pageURL = nextPageURL
        let loadID = UUID()

        activeLoadID = loadID
        isLoading = true
        loadError = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let page = try await HNRepository.shared.fetchListingPage(
                    listingType: self.listingType,
                    nextPageURL: pageURL
                )
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    isFirstPageFetch: isFirstPageFetch,
                    result: .success(page)
                )
            } catch is CancellationError {
                self.finishCancellation(loadID: loadID)
            } catch {
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    isFirstPageFetch: isFirstPageFetch,
                    result: .failure(error)
                )
            }
        }

        loadTask = task
        return task
    }

    private func finishLoad(
        loadID: UUID,
        reload: Bool,
        isFirstPageFetch: Bool,
        result: Result<ParsedHNListingPage, Error>
    ) {
        guard activeLoadID == loadID else { return }

        defer {
            loadTask = nil
            isLoading = false
        }

        switch result {
        case .success(let page):
            let newItems = page.items.map { cache?.canonicalize($0) ?? HNItem(parsed: $0) }
            nextPageURL = page.nextPageURL
            hasMoreContent = page.nextPageURL != nil

            if reload {
                items = newItems
            } else {
                items.append(contentsOf: newItems)
            }

            loadError = nil
            if isFirstPageFetch {
                lastUpdated = .now
                debugLog(
                    "listing/\(listingType)",
                    "loaded \(items.count) items\(reload ? " (reload)" : "")"
                )
            }

        case .failure(let error):
            loadError = error.localizedDescription
            debugLog("listing/\(listingType)", "load error: \(error.localizedDescription)")
        }
    }

    private func finishCancellation(loadID: UUID) {
        guard activeLoadID == loadID else { return }
        loadTask = nil
        isLoading = false
    }
}
