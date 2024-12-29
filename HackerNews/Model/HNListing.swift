//
//  Data.swift
//  HackerNews
//
//  Created by ejd on 9/23/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import Combine
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
    @Published var isLoading = true

    private var currentPage = 1

    init(_ listingType: ListingType) {
        self.listingType = listingType
        loadMoreContent()
    }

    func loadMoreContent(reload: Bool = false, completion: (() -> Void)? = nil) {
        isLoading = true
        if (reload) {
            self.currentPage = 1
        }

        Task {
            do {
                let url = "https://news.ycombinator.com/\(self.listingType)?p=\(self.currentPage)"
                self.currentPage = self.currentPage + 1

                let doc = try await RequestController.shared.makeRequest(endpoint: url)
                let newItems = self.parseItems(doc: doc)

                await MainActor.run {
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

}
