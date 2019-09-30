//
//  Comment.swift
//  HackerNews
//
//  Created by ejd on 9/30/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation

struct Comment: Identifiable {
    let id: Int
    let body: String
    let author: String
    let indentLevel: Int
    
    init?(withNode node: XMLElement) {
        self.id = Int(node.attr("id")!)!
        let textNode = node.firstChild(css: ".commtext")
        
        self.body = textNode!.stringValue
        
        self.author = node.firstChild(css: ".hnuser")!.stringValue
        
        let indentWidth = Int(node.firstChild(css: ".ind img")!.attr("width")!)!
        let indentLevel: Int = indentWidth / 40
        self.indentLevel = indentLevel
    }
    
}
