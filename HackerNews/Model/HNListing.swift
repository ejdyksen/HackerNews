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
        case .news: return "Top stories"
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

    private var nextPageUrl: String?

    init(_ listingType: ListingType) {
        self.listingType = listingType
    }

    func loadInitialContent() {
        if items.isEmpty {
            loadMoreContent()
        }
    }

    func loadMoreContent(reload: Bool = false, completion: (() -> Void)? = nil) {
        guard !isLoading else { return }

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
                self.isLoading = false
                completion?()
            } catch {
                self.isLoading = false
                self.loadError = error.localizedDescription
                completion?()
            }
        }
    }

    func parseItems(doc: HTMLDocument) -> [HNItem] {
        let itemList = doc.css("tr.athing")
        var newItems: [HNItem] = []

        for node in itemList {
            if let item = HNItem(withXmlNode: node) {
                newItems.append(item)
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
