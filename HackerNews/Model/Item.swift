//
//  Item.swift
//  HackerNews
//
//  Created by ejd on 9/27/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation

struct Item {
    let id: Int                 //req
    let title: String           //req
    let storyLink: URL          //req
//    let domain: String
    let age: String
    let score: Int?             //opt
    let author: String?
    let commentLink: URL?
    let commentCount: Int?
    
    
    init?(withNode node: XMLElement) {
        // Gather some additional XMLNodes
        guard
            let adjacentItem = node.xpath("./following-sibling::tr[1]").first,
            let storyLinkNode = node.xpath(".//a[@class='storylink']").first
            else {
                return nil
        }
        
        // Get an item ID, which is required
        guard let idString = node.attributes["id"], let id = Int(idString) else {
            return nil
        }
        self.id = id
  
        // Link to the story, which is required
        guard let href = storyLinkNode.attributes["href"], let storyLink = URL(string: href) else {
            return nil
        }
        self.storyLink = storyLink
        

        self.title = storyLinkNode.stringValue
        
        // Age, required
        guard let ageNode = adjacentItem.xpath(".//*[@class='age']").first else {
            return nil
        }
        self.age = ageNode.stringValue
        
        
        // Score, optional
        if
            let scoreString = adjacentItem.xpath(".//*[@id='score_\(self.id)']").first?.stringValue,
            let scoreStringComponent = scoreString.split(separator: " ").first,
            let score = Int(scoreStringComponent) {
            self.score = score
        } else {
            self.score = nil
        }
        
        // Author, optional
        self.author = adjacentItem.xpath(".//a[@class='hnuser']").first?.stringValue
        
        // Comment count, optional
        if
            let commentCountString = adjacentItem.xpath("./td/a[last()]").first?.stringValue,
            let commentCountComponent = commentCountString.split(separator: " ").first,
            let commentCount = Int(commentCountComponent) {
            self.commentCount = commentCount
        } else {
            self.commentCount = nil
        }
        
        // Comment URL, optional
        self.commentLink = URL(string: "https://news.ycombinator.com/item?id=\(self.id)")
    }
}
