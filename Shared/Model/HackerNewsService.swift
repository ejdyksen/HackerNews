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

class HackerNewsService: ObservableObject {
    @Published var topStories: [Item] = []
    private var page: Int = 1

    init() {
        
    }
    
    func reload() {
        page = 1
        topStories = []
        load()
    }
    
    func load() {
        let url = URL(string: "https://news.ycombinator.com/news?p=\(page)")!
        page = page + 1
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                print("Couldn't load \(url)")
                return
            }
            
            let newItems = self.parseTopStories(data: data)

            DispatchQueue.main.sync {
                self.topStories.append(contentsOf: newItems)
            }
        }
        dataTask.resume()
    }
    
    func parseTopStories(data: Data) -> [Item] {
        do {
            let doc = try HTMLDocument(data: data)
            let itemList = doc.css("table.itemlist tr.athing")

            var newItems: [Item] = []
            
            for node in itemList {
                if let item = Item(withNode: node) {
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
