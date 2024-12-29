//
//  Comment.swift
//  HackerNews
//
//  Created by ejd on 9/30/19.
//  Copyright 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi

class HNComment: Identifiable {
    let id: Int
    let author: String
    let age: String
    let indentLevel: Int
    let paragraphs: [String]
    var children: [HNComment] = []

    init(id: Int, author: String, age: String, indentLevel: Int, paragraphs: [String]) {
        self.id = id
        self.author = author
        self.age = age
        self.indentLevel = indentLevel
        self.paragraphs = paragraphs
    }

    static func createCommentTree(nodes: NodeSet) -> [HNComment] {
        var rootComments: [HNComment] = []

        var lastCommentAtLevel = [Int: HNComment]()

        for node in nodes {
            let id = Int(node.attr("id")!)!
            guard let textNode = node.firstChild(css: ".commtext") else {
                continue
            }

            var paragraphs: [String] = []

            for (_, child) in textNode.childNodes(ofTypes: [.Element, .Text]).enumerated() {
//                let childElement = child.toElement()
//
//                if childElement.type == .Text {
//                    paragraphs.append(childElement.)
//                }

                if child.type == .Text {
                    paragraphs.append(child.stringValue.trimmingCharacters(in: .newlines))
                } else if child.type == .Element {
                    paragraphs.append(child.stringValue.trimmingCharacters(in: .newlines))
                } else {
                    assert(false, "unhandled element type")
                }
            }

            let author = node.firstChild(css: ".hnuser")!.stringValue

            let age = node.firstChild(css: ".age")!.stringValue

            let indentWidth = Int(node.firstChild(css: ".ind img")!.attr("width")!)!
            let indentLevel: Int = indentWidth / 40

            let newComment = HNComment(id: id, author: author, age: age, indentLevel: indentLevel, paragraphs: paragraphs)

            lastCommentAtLevel[indentLevel] = newComment

            if (indentLevel > 0) {
                lastCommentAtLevel[indentLevel - 1]?.children.append(newComment)
            } else {
                rootComments.append(newComment)
            }
        }

        return rootComments
    }

}
