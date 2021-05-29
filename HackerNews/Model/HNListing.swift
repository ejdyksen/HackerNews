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

class HNListing: ObservableObject {
    let listingType: String

    @Published var items: [HNItem] = []
    @Published var isLoading = true

    private var currentPage = 1
    private var canLoadMorePages = true

    init(listingType: String) {
        self.listingType = listingType
        loadMoreContent()
    }

    func reload() {
        self.items = []
        self.currentPage = 1
        loadMoreContent()
    }

    func loadMoreContentIfNeeded(currentItem item: HNItem?) {
      guard let item = item else {
        loadMoreContent()
        return
      }

      let thresholdIndex = items.index(items.endIndex, offsetBy: -5)
      if items.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
        loadMoreContent()
      }
    }

    func loadMoreContent() {
        let url = URL(string: "https://news.ycombinator.com/\(listingType)?p=\(currentPage)")!
        currentPage = currentPage + 1
        DispatchQueue.global(qos: .userInitiated).async {
            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data else {
                    print("Couldn't load \(url)")
                    return
                }

                let newItems = self.parseItems(data: data)

                DispatchQueue.main.sync {
                    self.items.append(contentsOf: newItems)
                    self.isLoading = false
                }
            }
            dataTask.resume()
        }
    }

    func parseItems(data: Data) -> [HNItem] {
        do {
            let doc = try HTMLDocument(data: data)
            let itemList = doc.css("table.itemlist tr.athing")

            var newItems: [HNItem] = []

            for node in itemList {
                if let item = HNItem(withXmlNode: node) {
                    newItems.append(item)
                }
            }

            return newItems
        } catch {
            print("Error:", error)
            return []
        }
    }

}
