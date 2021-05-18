//
//  Item.swift
//  HackerNews
//
//  Created by ejd on 9/27/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi

class Item: ObservableObject, Identifiable {
    var id: Int                 //req
    let title: String           //req
    let storyLink: URL          //req
    let domain: String
    let age: String
    let author: String?

    var score: Int?
    var commentCount: Int?
    @Published var comments: [Comment] = []
    var itemLink: URL {
        get {
            return URL(string: "https://news.ycombinator.com/item?id=\(self.id)")!
        }
    }
    var subheading: String {
        if (score != nil && author != nil) {
            return "\(score!) points by \(author!) \(age)"
        } else if (score == nil && author != nil) {
            return "by \(author!) \(age)"
        } else if (score != nil && author == nil) {
            return "\(score!) points \(age)"
        } else {
            return age
        }
    }
    var commentSummary: String {
        if commentCount != nil {
            return String(commentCount!)
        } else {
            return ""
        }
    }


    init(id: Int, title: String, storyLink: URL, domain: String, age: String, author: String) {
        self.id = id
        self.title = title
        self.storyLink = storyLink
        self.domain = domain
        self.age = age
        self.author = author
        self.score = 0
        self.commentCount = 0
    }
    
    init?(withNode node: Fuzi.XMLElement) {
        // Gather some additional XMLNodes
        guard
            let adjacentItem = node.firstChild(xpath: "./following-sibling::tr[1]"),
            let storyLinkNode = node.firstChild(xpath: ".//a[@class='storylink']")
            else {
                return nil
        }
        
        // Get an item ID, which is required
        guard let idString = node.attributes["id"], let id = Int(idString) else {
            return nil
        }
        self.id = id
  
        // Link and title, which are required
        guard let href = storyLinkNode.attributes["href"], let storyLink = URL(string: href) else {
            return nil
        }
        self.storyLink = storyLink
        self.title = storyLinkNode.stringValue
        
        guard let domainNode = node.firstChild(css: ".sitestr") else {
            return nil
        }
        self.domain = domainNode.stringValue
        
        // Age, required
        guard let ageNode = adjacentItem.firstChild(css: ".age") else {
            return nil
        }
        self.age = ageNode.stringValue
        
        
        // Score, optional
        if
            let scoreString = adjacentItem.firstChild(css: "#score_\(self.id)")?.stringValue,
            let scoreStringComponent = scoreString.split(separator: " ").first,
            let score = Int(scoreStringComponent) {
            self.score = score
        } else {
            self.score = nil
        }
        
        // Author, optional
        self.author = adjacentItem.firstChild(css: ".hnuser")?.stringValue
        
        // Comment count, optional
        if let commentCountString = adjacentItem.firstChild(xpath: "./td/a[last()]")?.stringValue {
            let delimiterSet = CharacterSet.whitespaces
            let commentCountComponent = commentCountString.components(separatedBy: delimiterSet)
            let firstComponent = commentCountComponent.first!
            let commentCount = Int(firstComponent)
            self.commentCount = commentCount
        }
    }
    
    func loadComments() {
        DispatchQueue.global(qos: .userInteractive).async    {
            let dataTask = URLSession.shared.dataTask(with: self.itemLink) { data, response, error in
                do {
                    let doc = try HTMLDocument(data: data!)
                    let nodeList = doc.css("table.comment-tree tr.athing")

                    var newComments: [Comment] = []

                    for node in nodeList {
                        let newComment = Comment(withNode: node)
                        if (newComment != nil) {
                            newComments.append(newComment!)
                        }
                    }

                    DispatchQueue.main.sync {
                        self.comments = newComments
                    }

                } catch let error {
                  print(error)
                }
            }
            dataTask.resume()
        }
    }
}
