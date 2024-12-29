import Foundation
import Fuzi

enum ListingType: String {
    case news
    case ask
    case show
    case newest
    case jobs
}

class HNListing: ObservableObject {
    let listingType: ListingType

    @Published var items: [HNItem] = []
    @Published var isLoading = false
    @Published var hasMoreContent = false

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
        if (reload) {
            self.nextPageUrl = nil
        }

        Task {
            do {
                let url = self.nextPageUrl ?? "https://news.ycombinator.com/\(self.listingType)"
                let doc = try await RequestController.shared.makeRequest(endpoint: url)
                let newItems = self.parseItems(doc: doc)
                self.nextPageUrl = self.parseMoreLink(doc: doc)

                await MainActor.run {
                    self.hasMoreContent = self.nextPageUrl != nil

                    if (reload) {
                        self.items = newItems
                    } else {
                        self.items.append(contentsOf: newItems)
                    }
                    self.isLoading = false
                    completion?()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    completion?()
                }
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
        // Find the last <tr> in the table that contains the "More" link
        if let moreLink = doc.css("a").first(where: { $0.stringValue.trimmingCharacters(in: .whitespaces) == "More" }) {
            if let href = moreLink["href"] {
                return "https://news.ycombinator.com/\(href)"
            }
        }
        return nil
    }
}
