//
//  Data.swift
//  HackerNews
//
//  Created by ejd on 9/23/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import Combine

class HackerNewsService: ObservableObject {
    private let session: URLSession = .shared
    
    var cancellable: AnyCancellable?
    var storiesUpdate: AnyCancellable?
    
    @Published var topStories: [Item] = []
    
    init() {
        self.load()
    }

    func load() {
        DispatchQueue.global(qos: .userInteractive).async {
            let url = URL(string: "https://news.ycombinator.com/")!
            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
                do {
                    let doc = try HTMLDocument(data: data!)
                    let itemList = doc.xpath("//table[@class='itemlist']/tr[@class='athing']")

                    var newItems: [Item] = []

                    for node in itemList {
                        if let item = Item(withNode: node) {
                            newItems.append(item)
                        }
                    }

                    DispatchQueue.main.sync {
                        self.topStories = newItems
                    }

                } catch let error {
                  print(error)
                }
            }
            dataTask.resume()
        }
    }
}
