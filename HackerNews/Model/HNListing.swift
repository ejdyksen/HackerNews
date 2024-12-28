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

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(string: "https://news.ycombinator.com/\(self.listingType)?p=\(self.currentPage)")!
            self.currentPage = self.currentPage + 1

            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data else {
                    print("Couldn't load \(url)")
                    return
                }

                let newItems = self.parseItems(data: data)

                DispatchQueue.main.sync {
                    if (reload) {
                        self.items = newItems
                    } else {
                        self.items.append(contentsOf: newItems)
                    }
                    self.isLoading = false
                    if let completion = completion {
                        completion()
                    }
                }
            }
            dataTask.resume()
        }
    }

    func parseItems(data: Data) -> [HNItem] {
        do {
            let doc = try HTMLDocument(data: data)
            let itemList = doc.css("tr.athing")

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
