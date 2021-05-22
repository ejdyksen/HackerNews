//
//  Comment.swift
//  HackerNews
//
//  Created by ejd on 9/30/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi

struct Comment: Identifiable {
    let id: Int
    let author: String
    let indentLevel: Int
    var body: String = ""
    var paragraphs: [String] = []
    
    init(id: Int, body: String, author: String, indentLevel: Int) {
        self.id = id
        self.body = body
        self.author = author
        self.indentLevel = indentLevel
    }
    
    
    init?(withNode node: Fuzi.XMLElement) {
        self.id = Int(node.attr("id")!)!
        guard let textNode = node.firstChild(css: ".commtext") else {
            return nil
        }
                    
        self.body = textNode.stringValue
        
        for child in textNode.childNodes(ofTypes: [.Element, .Text]) {
            if child.type == .Text {
                paragraphs.append(child.stringValue.trimmingCharacters(in: .newlines))
            } else if child.type == .Element {
                paragraphs.append(child.stringValue.trimmingCharacters(in: .newlines))
            } else {
                assert(false, "unhandled element type")
            }
        }
        
        self.author = node.firstChild(css: ".hnuser")!.stringValue
        
        let indentWidth = Int(node.firstChild(css: ".ind img")!.attr("width")!)!
        let indentLevel: Int = indentWidth / 40
        self.indentLevel = indentLevel
    }
    
}
