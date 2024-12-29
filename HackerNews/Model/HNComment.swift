//
//  Comment.swift
//  HackerNews
//
//  Created by ejd on 9/30/19.
//  Copyright 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi
import SwiftUI

class HNComment: Identifiable {
    let id: Int
    let author: String
    let age: String
    let indentLevel: Int
    let content: AttributedString
    var children: [HNComment] = []

    init(id: Int, author: String, age: String, indentLevel: Int, content: AttributedString) {
        self.id = id
        self.author = author
        self.age = age
        self.indentLevel = indentLevel
        self.content = content
    }

    static func parseText(_ node: XMLElement) -> AttributedString {
        var result = AttributedString()

        // Handle text nodes and elements
        for child in node.childNodes(ofTypes: [.Element, .Text]) {
            if child.type == .Text {
                result += AttributedString(child.stringValue)
            } else if let element = child as? XMLElement {
                switch element.tag {
                case "p":
                    if result.characters.count > 0 {
                        result += AttributedString("\n\n")
                    }
                    result += parseText(element)
                case "i":
                    var italic = parseText(element)
                    italic.font = .italicSystemFont(ofSize: UIFont.systemFontSize)
                    result += italic
                case "pre", "code":
                    if result.characters.count > 0 {
                        result += AttributedString("\n\n")
                    }
                    var code = AttributedString(element.stringValue)
                    code.font = .monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
                    result += code
                case "a":
                    let href = element.attr("href") ?? ""
                    var displayUrl = href
                    if displayUrl.count > 50 {
                        displayUrl = String(displayUrl.prefix(47)) + "..."
                    }
                    var link = AttributedString(displayUrl)
                    if let url = URL(string: href) {
                        link.link = url
                    }
                    link.foregroundColor = .blue
                    result += link
                default:
                    result += parseText(element)
                }
            }
        }

        return result
    }

    static func createCommentTree(nodes: NodeSet) -> [HNComment] {
        var rootComments: [HNComment] = []
        var lastCommentAtLevel = [Int: HNComment]()

        for node in nodes {
            let id = Int(node.attr("id")!)!
            guard let textNode = node.firstChild(css: ".commtext") else {
                continue
            }

            // Parse the content into AttributedString
            let content = parseText(textNode)

            // Get other comment metadata
            let author = node.firstChild(css: ".comhead .hnuser")?.stringValue ?? ""
            let age = node.firstChild(css: ".comhead .age")?.stringValue ?? ""
            let indentLevel = (node.firstChild(css: ".ind img")?["width"].flatMap(Int.init) ?? 0) / 40

            let comment = HNComment(id: id, author: author, age: age, indentLevel: indentLevel, content: content)

            if indentLevel == 0 {
                rootComments.append(comment)
            } else if let parent = lastCommentAtLevel[indentLevel - 1] {
                parent.children.append(comment)
            }

            lastCommentAtLevel[indentLevel] = comment
        }

        return rootComments
    }
}
